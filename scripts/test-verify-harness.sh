#!/usr/bin/env bash
# Prova que o verificador aprova um harness válido e reprova cada defeito.
# Gera uma árvore mínima em diretório temporário; não toca no repositório.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY="$HERE/verify-harness.sh"
MANIFEST="$HERE/harness-manifest.txt"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

TESTS=0
FAILS=0

build_fixture() {
  python3 -I - "$1" "$MANIFEST" <<'PY'
import os, re, sys
root, manifest = sys.argv[1], sys.argv[2]
FILLER = "Conteúdo de exemplo usado apenas pelo teste do verificador. " * 8
SECTIONS = ["Objetivo", "Escopo", "Funcionalidades", "Dependências",
            "Arquivos e módulos esperados", "Critérios de aceite", "Testes",
            "Riscos", "Entregáveis", "Definition of Done", "Estratégia de revisão"]
ADR = ["Contexto", "Problema", "Alternativas", "Decisão", "Justificativa", "Consequências"]
PHASE_DATA = {
    "PHASE_00_HARNESS": (["00"], "NFR-HARNESS-001"),
    "PHASE_01_FOUNDATION": (["01"], ""),
    "PHASE_02_IDENTITY_SECURITY": (["02"], "NFR-SEC-001"),
    "PHASE_03_FOOD_AI": (["03"], "FR-FOOD-001"),
    "PHASE_04_STRAVA": (["04"], ""),
    "PHASE_05_GOALS": (["05.1", "05.2"], ""),
    "PHASE_06_GAMIFICATION": (["06"], ""),
    "PHASE_07_APPLICATIONS": (["07"], ""),
    "PHASE_08_INTELLIGENCE": (["08"], ""),
    "PHASE_09_PRODUCTION": (["09"], ""),
    "MILESTONE_M1_CLOSED_BETA": (["M1"], ""),
}
LINES = ["00", "01", "02", "03", "04", "05", "05.1", "05.2", "06", "07", "08", "09", "M1"]

def body(path):
    name = os.path.basename(path)
    stem = name[:-3] if name.endswith(".md") else name
    if path == ".claude/settings.json":
        return '{"enabledPlugins": {"superpowers@claude-plugins-official": true}, "permissions": {"deny": ["Read(**/.env)", "Read(**/.env.*)"]}}\n'
    if path == ".gitignore":
        return ".env\n"
    if path.startswith(".claude/agents/"):
        return f"---\nname: {stem}\ndescription: Revisor de exemplo\ntools: Read, Grep, Glob\nmodel: sonnet\n---\n\n{FILLER}\n"
    if path.startswith(".claude/skills/"):
        skill = path.split("/")[2]
        return f"---\nname: {skill}\ndescription: Skill de exemplo\n---\n\n{FILLER}\n"
    if path == ".claude/rules/backend.md":
        return f'---\npaths:\n  - "apps/api/**"\n---\n\n{FILLER}\n'
    if stem in PHASE_DATA:
        lines, req = PHASE_DATA[stem]
        out = [f"# {stem}\n", FILLER + "\n"]
        for s in SECTIONS:
            out.append(f"## {s}\n")
            if s == "Critérios de aceite":
                out += [f"- AC-{l}-01: comprovado por um comando.\n" for l in lines]
            elif s == "Objetivo" and req:
                out.append(f"Atende {req}.\n")
            else:
                out.append("Texto da seção.\n")
        return "\n".join(out)
    if re.match(r"\d{4}-", name):
        out = [f"# {stem}\n", FILLER + "\n"]
        for s in ADR:
            out += [f"## {s}\n", "Texto da seção.\n"]
        out += ["## Estado da decisão\n", "Proposta\n"]
        return "\n".join(out)
    if path.endswith("FUNCTIONAL_REQUIREMENTS.md"):
        return (f"# Requisitos\n\n{FILLER}\n\n| ID | Requisito | Prioridade |\n|---|---|---|\n"
                "| FR-FOOD-001 | Um requisito funcional. | M1 |\n"
                "| NFR-SEC-001 | Um requisito de segurança. | M1 |\n"
                "| NFR-HARNESS-001 | Um requisito do harness. | M1 |\n")
    if path.endswith("TRACEABILITY.md"):
        return (f"# Matriz\n\n{FILLER}\n\n| Requisito | Fase | ADR | Implementação | Teste | Critério de aceite |\n"
                "|---|---|---|---|---|---|\n"
                "| FR-FOOD-001 | 03 | — | — | — | AC-03-01 |\n"
                "| NFR-SEC-001 | 02 | 0001 | — | — | AC-02-01 |\n"
                "| NFR-HARNESS-001 | 00 | — | — | — | AC-00-01 |\n")
    if path.endswith("roadmap/STATUS.md"):
        rows = ""
        for l in LINES:
            st, ev = ("Em revisão", "spec") if l == "00" else ("Não iniciada", "—")
            rows += f"| {l} | {st} | 2026-11-05 | {ev} |\n"
        return (f"# Status\n\n{FILLER}\n\n## Estado atual\n\n| Linha | Estado | Desde | Evidência |\n|---|---|---|---|\n{rows}\n"
                "## Registro de transições\n\n| Data | Linha | De | Para | Evidência |\n|---|---|---|---|---|\n"
                "| 2026-11-05 | 00 | Não iniciada | Em revisão | spec |\n")
    return f"# {stem}\n\n{FILLER}\n"

for raw in open(manifest, encoding="utf-8"):
    path = raw.strip()
    if not path or path.startswith("#"):
        continue
    full = os.path.join(root, path)
    os.makedirs(os.path.dirname(full) or root, exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        f.write(body(path))
PY
}

set_state() { # arquivo STATUS.md, linha, estado, evidência
  python3 -I - "$1" "$2" "$3" "$4" <<'PY'
import re, sys
path, line, state, ev = sys.argv[1:5]
text = open(path, encoding="utf-8").read()
pat = re.compile(r"^\| %s \| ([^|]+) \| ([^|]+) \| ([^|]+) \|$" % re.escape(line), re.M)
old = pat.search(text).group(1).strip()
text = pat.sub(f"| {line} | {state} | 2026-11-06 | {ev} |", text, count=1)
text = text.rstrip("\n") + f"\n| 2026-11-06 | {line} | {old} | {state} | {ev} |\n"
open(path, "w", encoding="utf-8").write(text)
PY
}

BASE="$WORK/base"
mkdir -p "$BASE"
build_fixture "$BASE"

# run_case nome código_esperado check_esperado função_de_mutação [trecho_da_mensagem]
run_case() {
  local name="$1" want="$2" check="$3" mutate="$4" msg="${5:-}"
  local F="$WORK/case-$TESTS"
  cp -R "$BASE" "$F"
  TESTS=$((TESTS + 1))
  "$mutate" "$F"
  local out code
  out="$(bash "$VERIFY" "$F" 2>&1)"; code=$?
  local ok=1
  [ "$code" = "$want" ] || ok=0
  if [ -n "$check" ] && ! printf '%s\n' "$out" | grep -q "FALHA $check:.*$msg"; then ok=0; fi
  if printf '%s\n' "$out" | grep -q 'Traceback'; then ok=0; fi
  if [ "$ok" = 1 ]; then
    echo "ok   $name"
  else
    FAILS=$((FAILS + 1))
    echo "FAIL $name (esperado: código $want, check '$check'; obtido: código $code)"
    printf '%s\n' "$out" | sed -n '1,8p' | sed 's/^/     /'
  fi
  rm -rf "$F"
}

P=docs/product
PH=docs/roadmap/phases
ST=docs/roadmap/STATUS.md
MX=docs/roadmap/TRACEABILITY.md
ADR1=docs/architecture/decisions/0001-modular-monolith-monorepo.md
REQ=$P/FUNCTIONAL_REQUIREMENTS.md

m_none() { :; }
m_missing() { rm "$1/$P/PRD.md"; }
m_short() { printf '# PRD\n' > "$1/$P/PRD.md"; }
m_claude_long() { yes 'linha' | head -n 200 >> "$1/CLAUDE.md"; }
m_agent_desc() { sed -i '/^description:/d' "$1/.claude/agents/qa-reviewer.md"; }
m_agent_edit() { sed -i 's/^tools: .*/tools: Read, Edit/' "$1/.claude/agents/qa-reviewer.md"; }
m_skill_name() { sed -i '/^name:/d' "$1/.claude/skills/phase-kickoff/SKILL.md"; }
m_rule_paths() { sed -i '/^  - /d' "$1/.claude/rules/backend.md"; }
m_phase_section() { sed -i '/^## Riscos$/d' "$1/$PH/PHASE_03_FOOD_AI.md"; }
m_phase_ac() { sed -i 's/AC-03-01/critério sem identificador/' "$1/$PH/PHASE_03_FOOD_AI.md"; }
m_link() { echo '[x](nao-existe.md)' >> "$1/$P/PRD.md"; }
m_req_no_phase() {
  echo '| FR-GOALS-001 | Requisito sem fase. | M1 |' >> "$1/$REQ"
  echo '| FR-GOALS-001 | 03 | — | — | — | AC-03-01 |' >> "$1/$MX"
}
m_req_digit_prefix() { echo '| NFR-A11Y-001 | Requisito sem fase. | M1 |' >> "$1/$REQ"; }
m_phase_unknown() { echo 'Atende FR-FOOD-999.' >> "$1/$PH/PHASE_03_FOOD_AI.md"; }
m_req_no_matrix() { sed -i '/^| NFR-SEC-001 /d' "$1/$MX"; }
m_matrix_ac() { sed -i 's/AC-03-01/AC-03-99/' "$1/$MX"; }
m_done_no_test() { set_state "$1/$ST" 03 'Concluída' 'relatório'; }
m_00_done_ok() { set_state "$1/$ST" 00 'Concluída' 'relatório'; add_report "$1" PHASE_00_REPORT.md; }
add_report() { mkdir -p "$1/docs/roadmap/reports"; echo relatorio > "$1/docs/roadmap/reports/$2"; }
close_03() {
  set_state "$1/$ST" 03 'Em revisão' 'relatório'; set_state "$1/$ST" 03 'Concluída' 'aprovação'
  add_report "$1" PHASE_03_REPORT.md
}
m_done_fake_path() { close_03 "$1"; sed -i 's#^| FR-FOOD-001 | 03 | — | — | — |#| FR-FOOD-001 | 03 | — | apps/nao_existe.rb | spec/nao_existe.rb |#' "$1/$MX"; }
m_done_x_cells() { close_03 "$1"; sed -i 's#^| FR-FOOD-001 | 03 | — | — | — |#| FR-FOOD-001 | 03 | — | x | y |#' "$1/$MX"; }
m_done_real_path_ok() { close_03 "$1"; sed -i 's#^| FR-FOOD-001 | 03 | — | — | — |#| FR-FOOD-001 | 03 | — | `README.md` | `CLAUDE.md`, `README.md:3` |#' "$1/$MX"; }
m_done_gap_ok() { close_03 "$1"; sed -i 's#^| FR-FOOD-001 | 03 | — | — | — |#| FR-FOOD-001 | 03 | — | Lacuna aceita em 2026-11-06 | `README.md`. Lacuna aceita em 2026-11-06 |#' "$1/$MX"; }
m_done_no_report() { set_state "$1/$ST" 00 'Concluída' 'relatório'; }
m_done_not_review() { set_state "$1/$ST" 09 'Em desenvolvimento' 'plano'; set_state "$1/$ST" 09 'Concluída' 'relatório'; add_report "$1" PHASE_09_REPORT.md; }
m_done_dash_ev() { set_state "$1/$ST" 00 'Concluída' '-'; add_report "$1" PHASE_00_REPORT.md; }
m_agent_no_frontmatter() { echo 'Sem frontmatter' > "$1/.claude/agents/qa-reviewer.md"; }
m_skill_no_frontmatter() { echo 'Sem frontmatter' > "$1/.claude/skills/phase-kickoff/SKILL.md"; }
m_matrix_unknown_req() { echo '| FR-FOOD-999 | 03 | — | — | — | AC-03-01 |' >> "$1/$MX"; }
m_matrix_no_ac() { sed -i 's/^| FR-FOOD-001 | 03 | — | — | — | AC-03-01 |/| FR-FOOD-001 | 03 | — | — | — | — |/' "$1/$MX"; }
m_tools_absent() { sed -i '/^tools:/d' "$1/.claude/agents/qa-reviewer.md"; }
m_name_mismatch() { sed -i 's/^name: .*/name: outro/' "$1/.claude/agents/qa-reviewer.md"; }
m_tools_inline() { sed -i 's/^tools: .*/tools: [Read, Edit]/' "$1/.claude/agents/qa-reviewer.md"; }
m_tools_star() { sed -i 's/^tools: .*/tools: "*"/' "$1/.claude/agents/qa-reviewer.md"; }
m_tools_multiedit() { sed -i 's/^tools: .*/tools: Read, MultiEdit/' "$1/.claude/agents/qa-reviewer.md"; }
m_skill_name_mismatch() { sed -i 's/^name: .*/name: outro/' "$1/.claude/skills/phase-kickoff/SKILL.md"; }
m_skill_no_desc() { sed -i '/^description:/d' "$1/.claude/skills/phase-kickoff/SKILL.md"; }
m_paths_inline_empty() { sed -i '/^  - /d; s/^paths:$/paths: []/' "$1/.claude/rules/backend.md"; }
m_section_order() { python3 -I - "$1/$PH/PHASE_03_FOOD_AI.md" <<'EOP'
import sys
p=sys.argv[1]; t=open(p,encoding='utf-8').read()
open(p,'w',encoding='utf-8').write(t.replace('## Riscos','## TEMP').replace('## Testes','## Riscos').replace('## TEMP','## Testes'))
EOP
}
m_req_twice() { echo '| FR-FOOD-001 | Repetido. | M1 |' >> "$1/$REQ"; }
m_matrix_cols() { sed -i 's/^| FR-FOOD-001 | 03 | — | — | — | AC-03-01 |/| FR-FOOD-001 | 03 | AC-03-01 |/' "$1/$MX"; }
m_matrix_phase() { sed -i 's/^| FR-FOOD-001 | 03 |/| FR-FOOD-001 | 99 |/' "$1/$MX"; }
m_matrix_moved() { sed -i 's/^| FR-FOOD-001 | 03 |/| FR-FOOD-001 | 09 |/' "$1/$MX"; }
m_matrix_foreign_ac() { sed -i 's/^| FR-FOOD-001 | 03 | — | — | — | AC-03-01 |/| FR-FOOD-001 | 03 | — | — | — | AC-09-01 |/' "$1/$MX"; }
m_matrix_dup() { echo '| NFR-SEC-001 | 02 | 0001 | — | — | AC-02-01 |' >> "$1/$MX"; }
m_matrix_adr() { sed -i 's/^| NFR-SEC-001 | 02 | 0001 |/| NFR-SEC-001 | 02 | 9999 |/' "$1/$MX"; }
m_status_date() { echo '| ontem | 09 | Não iniciada | Não iniciada | x |' >> "$1/$ST"; }
m_status_unknown() { sed -i 's/^| 09 | Não iniciada /| 99 | Não iniciada /' "$1/$ST"; }
m_status_log_unknown() { echo '| 2026-11-06 | 99 | Não iniciada | Em revisão | x |' >> "$1/$ST"; }
m_status_log_state() { echo '| 2026-11-06 | 09 | Não iniciada | Pronta | x |' >> "$1/$ST"; }
m_status_log_cols() { echo '| 2026-11-06 | 09 | Não iniciada |' >> "$1/$ST"; }
m_transition_no_ev() { set_state "$1/$ST" 09 'Em planejamento' '—'; }
m_transition_gap() { echo '| 2026-11-06 | 09 | Em revisão | Não iniciada | x |' >> "$1/$ST"; }
m_status_one_col() { sed -i 's/^| M1 | .*/| M1 |/' "$1/$ST"; }
m_05_open_summary() { set_state "$1/$ST" 05.1 'Em revisão' 'r'; set_state "$1/$ST" 05.1 'Concluída' 'a'; set_state "$1/$ST" 05.2 'Em revisão' 'r'; set_state "$1/$ST" 05.2 'Concluída' 'a'; add_report "$1" PHASE_05.1_REPORT.md; add_report "$1" PHASE_05.2_REPORT.md; }
m_ac_no_proof() { sed -i 's/AC-03-01: comprovado por um comando\./AC-03-01: funciona./' "$1/$PH/PHASE_03_FOOD_AI.md"; }
m_ac_dup() { sed -i 's/^- AC-03-01: \(.*\)$/- AC-03-01: \1\n- AC-03-01: \1/' "$1/$PH/PHASE_03_FOOD_AI.md"; }
m_fence_heading_ok() { python3 -I - "$1/$PH/PHASE_03_FOOD_AI.md" <<'EOP'
import sys
p=sys.argv[1]; t=open(p,encoding='utf-8').read()
open(p,'w',encoding='utf-8').write(t.replace('## Critérios de aceite\n','## Critérios de aceite\n\n```text\n## Exemplo\n```\n'))
EOP
}
m_indented_fence_ok() { printf -- '- Item:\n\n  ```text\n  [x](nao-existe.md) TBD\n  ```\n' >> "$1/$P/PRD.md"; }
m_uppercase_word_ok() { echo 'TODO USUÁRIO ADULTO PODE ENTRAR.' >> "$1/$P/PRD.md"; }
m_todo_colon() { echo 'TODO: decidir isto.' >> "$1/$P/PRD.md"; }
m_planning_blocked() { set_state "$1/$ST" 01 'Em planejamento' 'autorização'; mkdir -p "$1/apps/api"; }
m_worktree_ok() { mkdir -p "$1/.claude/worktrees/w/docs"; printf '[x](nao-existe.md) TBD\n' > "$1/.claude/worktrees/w/docs/a.md"; }
m_settings_array() { echo '[]' > "$1/.claude/settings.json"; }
m_settings_deny() { echo '{"enabledPlugins": {"superpowers@claude-plugins-official": true}}' > "$1/.claude/settings.json"; }
m_superpowers_exempt_ok() { mkdir -p "$1/docs/superpowers/plans"; echo 'TBD' > "$1/docs/superpowers/plans/a.md"; }
m_unquote_ok() { echo 'conteudo' > "$1/$P/com espaco.md"; echo '[x](com%20espaco.md)' >> "$1/$P/PRD.md"; }
m_claude_199_ok() { head -c 0 /dev/null > "$1/CLAUDE.md"; yes 'linha com conteudo suficiente para o minimo exigido' | head -n 199 > "$1/CLAUDE.md"; }
m_crlf_defect() { m_link "$1"; find "$1" -type f -exec sed -i 's/$/\r/' {} +; }
m_adr_section() { sed -i '/^## Alternativas$/d' "$1/$ADR1"; }
m_adr_state() { sed -i 's/^Proposta$/Talvez/' "$1/$ADR1"; }
m_status_state() { sed -i 's/^| 09 | Não iniciada /| 09 | Pronta /' "$1/$ST"; }
m_status_line() { sed -i '/^| M1 | /d' "$1/$ST"; }
m_status_no_ev() { set_state "$1/$ST" 09 'Concluída' '—'; }
m_status_two() { set_state "$1/$ST" 03 'Em desenvolvimento' 'plano'; set_state "$1/$ST" 04 'Em desenvolvimento' 'plano'; }
m_status_05_ok() { set_state "$1/$ST" 05 'Em desenvolvimento' 'plano'; set_state "$1/$ST" 04 'Em desenvolvimento' 'plano'; }
m_status_05_done() { set_state "$1/$ST" 05 'Concluída' 'relatório'; }
m_status_disagree() { sed -i 's/^| 09 | Não iniciada /| 09 | Em revisão /' "$1/$ST"; }
m_placeholder() { echo 'Falta decidir: TBD.' >> "$1/$P/PRD.md"; }
m_apps() { mkdir -p "$1/apps/api"; }
m_compose() { echo 'services: {}' > "$1/docker-compose.yml"; }
m_apps_allowed() { set_state "$1/$ST" 01 'Em desenvolvimento' 'plano aprovado'; mkdir -p "$1/apps/api"; }
m_settings_json() { echo '{ invalido' > "$1/.claude/settings.json"; }
m_settings_plugin() { echo '{"enabledPlugins": {}}' > "$1/.claude/settings.json"; }
m_placeholder_ok() {
  printf 'Regra sobre `TODO` crítico.\n\n```text\nTBD\n```\n' >> "$1/$P/PRD.md"
}
m_anchor_ok() { echo '[x](PRD.md#visao)' >> "$1/$P/PRD.md"; }
m_fence_ok() { printf '```text\n[x](nao-existe.md)\n```\n' >> "$1/$P/PRD.md"; }
m_external_ok() { echo '[a](https://exemplo.org/b) [c](mailto:d@exemplo.org)' >> "$1/$P/PRD.md"; }
m_template_ok() {
  echo 'TBD' >> "$1/docs/roadmap/PHASE_TEMPLATE.md"
  echo 'TBD' >> "$1/docs/architecture/decisions/TEMPLATE.md"
  echo 'TBD' >> "$1/$P/MASTER_PROMPT.md"
}
m_crlf_ok() { find "$1" -type f -exec sed -i 's/$/\r/' {} +; }

run_case valid_fixture_passes 0 '' m_none
run_case missing_required_file 1 required m_missing
run_case too_short_file 1 required m_short
run_case claude_md_too_long 1 claude-md m_claude_long
run_case agent_without_description 1 frontmatter m_agent_desc
run_case agent_with_edit_tool 1 frontmatter m_agent_edit
run_case skill_without_name 1 frontmatter m_skill_name
run_case rule_paths_invalid 1 frontmatter m_rule_paths
run_case phase_missing_section 1 phase-sections m_phase_section
run_case phase_without_acceptance_id 1 phase-sections m_phase_ac
run_case broken_link 1 links m_link
run_case requirement_without_phase 1 traceability m_req_no_phase 'requisito sem fase'
run_case requirement_id_with_digit_is_tracked 1 traceability m_req_digit_prefix
run_case phase_cites_unknown_requirement 1 traceability m_phase_unknown
run_case requirement_missing_in_matrix 1 traceability m_req_no_matrix
run_case matrix_unknown_acceptance 1 traceability m_matrix_ac
run_case done_phase_without_test 1 traceability m_done_no_test 'sem implementação e teste'
run_case phase_00_done_without_code_ok 0 '' m_00_done_ok
run_case adr_missing_section 1 adr m_adr_section
run_case adr_invalid_state 1 adr m_adr_state
run_case status_invalid_state 1 status m_status_state 'estado inválido em 09'
run_case status_missing_line 1 status m_status_line
run_case status_done_without_evidence 1 status m_status_no_ev 'concluída sem evidência'
run_case status_two_active 1 status m_status_two 'mais de uma linha'
run_case status_05_summary_active_ok 0 '' m_status_05_ok
run_case status_05_done_with_open_stage 1 status m_status_05_done '05 concluída com etapa'
run_case status_table_disagrees_with_log 1 status m_status_disagree 'o registro indica'
run_case placeholder_in_doc 1 placeholder m_placeholder
run_case product_code_before_phase_01 1 scope m_apps
run_case compose_before_phase_01 1 scope m_compose
run_case product_code_allowed_after_01 0 '' m_apps_allowed
run_case settings_invalid_json 1 settings m_settings_json
run_case settings_without_superpowers 1 settings m_settings_plugin 'não habilitado'
run_case placeholder_in_backticks_ok 0 '' m_placeholder_ok
run_case link_with_anchor_ok 0 '' m_anchor_ok
run_case link_in_code_fence_ok 0 '' m_fence_ok
run_case external_link_ignored 0 '' m_external_ok
run_case template_exempt 0 '' m_template_ok
run_case crlf_files_ok 0 '' m_crlf_ok
run_case crlf_still_detects_defect 1 links m_crlf_defect 'nao-existe'
run_case done_fake_path_rejected 1 traceability m_done_fake_path 'caminho inexistente'
run_case done_any_text_rejected 1 traceability m_done_x_cells 'caminho inexistente'
run_case done_real_path_ok 0 '' m_done_real_path_ok
run_case done_accepted_gap_ok 0 '' m_done_gap_ok
run_case done_requires_report 1 status m_done_no_report 'sem relatório'
run_case done_only_from_review 1 status m_done_not_review 'em revisão'
run_case done_ascii_dash_is_empty 1 status m_done_dash_ev 'concluída sem evidência'
run_case agent_without_frontmatter 1 frontmatter m_agent_no_frontmatter 'frontmatter ausente'
run_case skill_without_frontmatter 1 frontmatter m_skill_no_frontmatter 'frontmatter ausente'
run_case matrix_unknown_requirement 1 traceability m_matrix_unknown_req 'requisito inexistente'
run_case matrix_without_acceptance 1 traceability m_matrix_no_ac 'sem critério de aceite'
run_case agent_tools_absent 1 frontmatter m_tools_absent 'tools ausente'
run_case agent_name_mismatch 1 frontmatter m_name_mismatch 'name deve ser'
run_case agent_inline_list_with_edit 1 frontmatter m_tools_inline 'não pode ter'
run_case agent_tools_star 1 frontmatter m_tools_star 'não pode ter'
run_case agent_multiedit 1 frontmatter m_tools_multiedit 'não pode ter'
run_case skill_name_mismatch 1 frontmatter m_skill_name_mismatch 'name deve ser'
run_case skill_without_description 1 frontmatter m_skill_no_desc 'description ausente'
run_case rule_paths_inline_empty 1 frontmatter m_paths_inline_empty 'paths vazio'
run_case section_out_of_order 1 phase-sections m_section_order 'fora de ordem'
run_case ac_without_proof 1 phase-sections m_ac_no_proof 'sem forma de comprovação'
run_case ac_duplicated 1 phase-sections m_ac_dup 'repetido'
run_case requirement_defined_twice 1 traceability m_req_twice 'mais de uma vez'
run_case matrix_wrong_columns 1 traceability m_matrix_cols 'colunas'
run_case matrix_invalid_phase 1 traceability m_matrix_phase 'fase inválida'
run_case matrix_row_moved_to_other_line 1 traceability m_matrix_moved 'não cita'
run_case matrix_foreign_acceptance 1 traceability m_matrix_foreign_ac 'não pertence'
run_case matrix_duplicate_row 1 traceability m_matrix_dup 'repetida'
run_case matrix_unknown_adr 1 traceability m_matrix_adr 'ADR inexistente'
run_case status_bad_date 1 status m_status_date 'data inválida'
run_case status_unknown_line 1 status m_status_unknown 'linha desconhecida'
run_case status_log_unknown_line 1 status m_status_log_unknown 'desconhecida na transição'
run_case status_log_invalid_state 1 status m_status_log_state 'inválido na transição'
run_case status_log_wrong_columns 1 status m_status_log_cols 'transição com'
run_case transition_without_evidence 1 status m_transition_no_ev 'sem evidência'
run_case transition_not_continuous 1 status m_transition_gap 'descontínua'
run_case status_one_column_row 1 status m_status_one_col 'colunas'
run_case status_05_summary_must_close 1 status m_05_open_summary 'etapas concluídas'
run_case fenced_heading_in_criteria_ok 0 '' m_fence_heading_ok
run_case indented_fence_ok 0 '' m_indented_fence_ok
run_case uppercase_portuguese_word_ok 0 '' m_uppercase_word_ok
run_case todo_with_colon_rejected 1 placeholder m_todo_colon 'TODO'
run_case product_code_blocked_in_planning 1 scope m_planning_blocked
run_case worktrees_not_scanned_ok 0 '' m_worktree_ok
run_case settings_array_rejected 1 settings m_settings_array 'objeto'
run_case settings_without_secret_deny 1 settings m_settings_deny 'deny'
run_case docs_superpowers_exempt_ok 0 '' m_superpowers_exempt_ok
run_case link_with_encoded_space_ok 0 '' m_unquote_ok
run_case claude_md_199_lines_ok 0 '' m_claude_199_ok

# Manifesto ausente
TESTS=$((TESTS + 1))
if python3 -I "$HERE/verify_harness.py" "$BASE" "$WORK/nao-existe.txt" 2>&1 | grep -q 'FALHA required:.*manifesto não encontrado'; then
  echo "ok   manifest_missing"
else
  FAILS=$((FAILS + 1)); echo "FAIL manifest_missing"
fi

# Caminho com espaços
TESTS=$((TESTS + 1))
SPACED="$WORK/pasta com espaco"
cp -R "$BASE" "$SPACED"
if bash "$VERIFY" "$SPACED" >/dev/null 2>&1; then
  echo "ok   path_with_spaces_ok"
else
  FAILS=$((FAILS + 1)); echo "FAIL path_with_spaces_ok"
fi

# Outro diretório de trabalho
TESTS=$((TESTS + 1))
if (cd / && bash "$VERIFY" "$BASE" >/dev/null 2>&1); then
  echo "ok   run_from_other_cwd_ok"
else
  FAILS=$((FAILS + 1)); echo "FAIL run_from_other_cwd_ok"
fi

echo "$TESTS testes, $FAILS falhas"
[ "$FAILS" = 0 ]
