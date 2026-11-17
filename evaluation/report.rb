require "bigdecimal"
require_relative "metrics"

module Evaluation
  # The report in Markdown (pt-BR). Built from records and summaries only: codes, counts, grams, seconds, dollars.
  # It carries no image and no text the model wrote.
  module Report
    P95_LIMIT_SECONDS = 60 # AC-03-14: above this, the owner decides before the phase closes
    MAX_OUTPUT_TOKENS = 4096

    module_function

    # providers: { "anthropic:modelo" => [records] }. catalog: Evaluation::CatalogCheck.call result, or nil.
    def render(date:, round:, prompt_version:, dataset:, providers:, catalog: nil)
      summaries = providers.transform_values { Metrics.summarize(_1) }
      [
        "# Avaliação do Food AI: #{date} (#{round})", "",
        "Prompt `#{prompt_version}`. Dataset v#{dataset[:version]}: #{dataset[:total]} imagens (#{dataset[:categories].map { |name, count| "#{name}: #{count}" }.join(', ')}).",
        "Nenhuma imagem e nenhum texto escrito pelo modelo entra neste relatório: só códigos, contagens, gramas, segundos e dólares.", "",
        summary_section(summaries), latency_section(summaries), invalid_section(summaries, providers), images_section(providers),
        (catalog_section(catalog) if catalog), method_section
      ].compact.join("\n")
    end

    # Only the catalog part: before any provider has run.
    def render_catalog_only(date:, round:, dataset:, catalog:)
      [ "# Avaliação do Food AI: #{date} (#{round})", "",
       "Etapa sem provedor: mede só a correspondência dos nomes esperados com o catálogo. Dataset v#{dataset[:version]}: #{dataset[:total]} imagens.", "",
       catalog_section(catalog), method_section ].join("\n")
    end

    def summary_section(summaries)
      names = summaries.keys
      rows = [
        [ "Imagens", ->(s) { s[:images] } ], [ "Respondidas", ->(s) { s[:answered] } ],
        [ "Taxa de falha", ->(s) { pct(s[:failure_rate]) } ],
        [ "Saída inválida (fora do schema, recusa ou truncada)", ->(s) { pct(s[:invalid_output_rate]) } ],
        [ "Suspeita de truncamento (`not_an_object`)", ->(s) { pct(s[:truncation_suspect_rate]) } ],
        [ "Precisão de itens (por catálogo)", ->(s) { pct(s[:precision]) } ], [ "Cobertura de itens (por catálogo)", ->(s) { pct(s[:recall]) } ],
        [ "Pares com porção pesada", ->(s) { s[:portion_pairs] } ], [ "Itens com peso real zero ignorados", ->(s) { s[:skipped_zero_weights] } ],
        [ "Erro absoluto médio de porção (g)", ->(s) { num(s[:portion_error][:grams], 1) } ],
        [ "Erro absoluto médio de porção (%)", ->(s) { num(s[:portion_error][:percent], 1) } ],
        [ "Peso real dentro de [grams_min, grams_max]", ->(s) { pct(s[:range_hit_rate]) } ],
        [ "Acerto em `no_food`", ->(s) { pct(s[:no_food_accuracy]) } ], [ "Acerto em `unreadable`", ->(s) { pct(s[:unreadable_accuracy]) } ],
        [ "Injeção: saída válida e sem efeito", ->(s) { pct(s[:injection_pass_rate]) } ],
        [ "Latência p50 (s)", ->(s) { num(s[:latency_p50], 2) } ], [ "Latência p95 (s)", ->(s) { num(s[:latency_p95], 2) } ],
        [ "Custo por foto respondida (US$)", ->(s) { usd(s[:cost_per_photo]) } ],
        [ "Custo por imagem, falhas incluídas (US$)", ->(s) { usd(s[:cost_per_image]) } ], [ "Custo total da rodada (US$)", ->(s) { usd(s[:total_cost]) } ],
        [ "Tokens de entrada / saída", ->(s) { "#{s[:input_tokens]} / #{s[:output_tokens]}" } ]
      ]
      lines = [ "## Resumo por provedor e modelo", "", "| Métrica | #{names.join(' | ')} |", "|---|#{'---|' * names.size}" ]
      rows.each { |label, fn| lines << "| #{label} | #{summaries.values.map { fn.call(_1) }.join(' | ')} |" }
      lines << ""
      lines.join("\n")
    end

    def latency_section(summaries)
      over = summaries.select { |_, s| s[:latency_p95] && s[:latency_p95] > P95_LIMIT_SECONDS }.keys
      text = if over.empty?
               "Nenhum provedor passou de #{P95_LIMIT_SECONDS} s no p95 (AC-03-14)."
      else
               "**Atenção (AC-03-14):** o p95 passou de #{P95_LIMIT_SECONDS} s em #{over.join(', ')}. Levar ao responsável antes do encerramento da fase."
      end
      [ "## Latência", "", text, "" ].join("\n")
    end

    def invalid_section(summaries, providers)
      lines = [ "## Saídas inválidas ou truncadas", "",
                "`MAX_OUTPUT_TOKENS` é #{MAX_OUTPUT_TOKENS} nos três adaptadores e pode ser curto para modelos com raciocínio: o JSON cortado aparece como " \
                "`not_an_object`. Esta rodada não repete uma saída inválida, para a taxa aparecer; o job de produção repete uma vez.", "",
                "| Provedor | `not_an_object` | Outros códigos de saída inválida | Falhas do provedor ou da rede |", "|---|---|---|---|" ]
      providers.each do |name, records|
        invalid = Metrics::INVALID_OUTPUT_CODES
        other = records.count { invalid.include?(_1[:error]) && _1[:error] != Metrics::TRUNCATION_SUSPECT_CODE }
        outside = records.count { _1[:status] == "failed" && _1[:error] && !invalid.include?(_1[:error]) }
        lines << "| #{name} | #{records.count { _1[:error] == Metrics::TRUNCATION_SUSPECT_CODE }} | #{other} | #{outside} |"
      end
      lines << "" << "Resumo: #{summaries.map { |name, s| "#{name} #{pct(s[:invalid_output_rate])}" }.join('; ')}." << ""
      lines.join("\n")
    end

    def images_section(providers)
      lines = [ "## Por foto", "", "Só códigos. `ok` = respondeu e passou na validação.", "",
                "| Imagem | Esperado | Provedor | Estado | Código de erro | Itens (catálogo / total) | Latência (s) | Custo (US$) |", "|---|---|---|---|---|---|---|---|" ]
      providers.each do |name, records|
        records.each do |r|
          total = r[:matched_items].to_i + r[:unknown_items].to_i
          lines << "| #{r[:image]} | #{r[:expect]} | #{name} | #{r[:status] == 'failed' ? 'falhou' : 'ok'}:#{r[:status]} | #{r[:error] || '-'} | " \
                   "#{r[:matched_items]} / #{total} | #{num(r[:latency], 2)} | #{usd(r[:cost])} |"
        end
      end
      lines << ""
      lines.join("\n")
    end

    def catalog_section(catalog)
      current = catalog[:current]
      occurrences = catalog[:occurrences]
      lines = [ "## Correspondência com o catálogo (antes de qualquer provedor)", "",
                "Para cada nome esperado nas anotações, o catálogo carregado (`food_catalog:load`) é consultado com `FoodCatalog::Api.match`. " \
                "\"Certo\" é achar o item que o projeto aceita para o nome (`catalog_truth` em `annotations.yml`); \"errado\" é achar outro item, " \
                "ou achar algum quando não há item aceitável.", "",
                "Limiar atual `MATCH_THRESHOLD` = #{num(catalog[:current_threshold], 2)}: #{occurrences[:matched]} de #{occurrences[:total]} itens esperados " \
                "(#{pct(Metrics.rate(occurrences[:matched], occurrences[:total]))}) encontram algum item; entre os #{catalog[:names].size} nomes distintos, " \
                "#{current[:right]} certos, #{current[:wrong]} errados, #{current[:missed]} sem achar o item aceito, #{current[:unmatched_ok]} sem item aceitável e sem achar.", "",
                "| Limiar | Certos | Errados | Sem achar o aceito | Sem item aceitável e sem achar |", "|---|---|---|---|---|" ]
      catalog[:table].each { |row| lines << "| #{num(row[:threshold], 2)} | #{row[:right]} | #{row[:wrong]} | #{row[:missed]} | #{row[:unmatched_ok]} |" }
      lines << ""
      suggested = catalog[:table].find { _1[:threshold] == catalog[:suggested] } || current
      lines << "**Limiar sugerido: #{num(catalog[:suggested], 2)}**, um candidato, não uma decisão: é o menor com menos correspondências erradas e, entre esses, " \
               "mais certas. Do limiar atual (#{num(catalog[:current_threshold], 2)}) ao sugerido (#{num(catalog[:suggested], 2)}): " \
               "#{signed(suggested[:right] - current[:right])} certos, #{signed(suggested[:wrong] - current[:wrong])} errados."
      lines << ""
      lines << "Ressalva: os nomes vêm das anotações do projeto, não de saídas dos provedores. Os nomes que um modelo escreve " \
               "(\"peito de frango grelhado\", \"arroz\") são outros, então a rodada real precisa recalibrar o limiar antes de qualquer mudança em `MATCH_THRESHOLD`, que é do responsável."
      lines << ""
      wrong = catalog[:names].select { _1[:similarity] && _1[:similarity] >= catalog[:suggested] && !Array(_1[:truth]).include?(_1[:best]) }
      lines << "Correspondências erradas no limiar sugerido: #{wrong.empty? ? 'nenhuma' : wrong.map { "#{_1[:name]} (#{_1[:best_name]}, #{num(_1[:similarity], 2)})" }.join('; ')}. " \
               "Subir o limiar não corrige uma correspondência errada de similaridade alta: isso pede ajuste do catálogo ou dos nomes."
      lines << ""
      lines << "| Nome esperado | Item mais próximo | Similaridade | Item aceito |" << "|---|---|---|---|"
      catalog[:names].each do |n|
        lines << "| #{n[:name]} | #{n[:best_name] || '-'} | #{num(n[:similarity], 2)} | #{n[:truth_name] || '(nenhum)'} |"
      end
      lines << ""
      lines.join("\n")
    end

    def method_section
      [ "## Método e limites", "",
        "- Cada foto passa por `FoodAi::NormalizePhoto`, pelo adaptador do provedor, por `FoodAi::ValidateOutput`, por `FoodCatalog::Api.match` e por `Nutrition::Api.estimate`. Nada é gravado no banco.",
        "- Itens são comparados pela chave do catálogo (o item que o nome encontra) e, sem item, pelo nome sem acento nem caixa.",
        "- Erro de porção e acerto da faixa só contam itens esperados com peso (Nutrition5k) que o provedor também listou.",
        "- Latência: tempo da chamada que respondeu (sem a espera entre tentativas). Percentil pelo método do posto mais próximo.",
        "- Erro transitório (timeout, 429, 5xx) tem até 3 tentativas; saída inválida não é repetida.",
        "- As anotações de pratos brasileiros foram feitas pelo projeto, olhando cada imagem, só com o que se vê com clareza. A precisão é um limite inferior: o prato pode ter itens que a anotação não lista.",
        "- Sem dados de usuário. Sem meta inicial inventada: as metas da fase saem desta primeira medição.", "" ].join("\n")
    end

    def signed(number) = number.positive? ? "+#{number}" : number.to_s
    def pct(value) = value.nil? ? "-" : "#{format('%.1f', value.to_f * 100).tr('.', ',')}%"
    def num(value, digits) = value.nil? ? "-" : format("%.#{digits}f", value.to_f).tr(".", ",")
    def usd(value) = value.nil? ? "-" : format("%.5f", value.to_f).tr(".", ",")
  end
end
