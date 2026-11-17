#!/usr/bin/env bash
# Prova que check_language.py reprova cada termo proibido e aprova texto limpo.
# Gera árvores mínimas em diretório temporário; não toca no repositório.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/check_language.py"
DENY="$HERE/language_denylist.txt"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

TESTS=0
FAILS=0
OUT=""
CODE=0

fresh() { rm -rf "$WORK/root"; mkdir -p "$WORK/root"; }
put() { mkdir -p "$(dirname "$WORK/root/$1")"; printf '%s\n' "$2" > "$WORK/root/$1"; }
: > "$WORK/allow_empty.txt"
run() { OUT="$(python3 -I "$CHECK" --root "$WORK/root" --denylist "${1:-$DENY}" --allow "${2:-$WORK/allow_empty.txt}" 2>&1)"; CODE=$?; }

expect() { # name, ok|fail
  TESTS=$((TESTS + 1))
  if [ "$2" = ok ]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    echo "$OUT" | sed 's/^/     /'
    FAILS=$((FAILS + 1))
  fi
}

passes() { # name, path, text
  fresh; put "$2" "$3"; run
  if [ "$CODE" -eq 0 ]; then expect "$1" ok; else expect "$1" fail; fi
}

reports() { # name, path, text, expected-substring
  fresh; put "$2" "$3"; run
  if [ "$CODE" -eq 1 ] && echo "$OUT" | grep -qF -- "$4"; then expect "$1" ok; else expect "$1" fail; fi
}

reports "planted 'calorias restantes' fails with file:line:term" \
  apps/mobile/src/features/meals/Summary.tsx $'ok\nVocê tem 300 calorias restantes.' \
  "apps/mobile/src/features/meals/Summary.tsx:2:calorias restantes"
passes "clean file passes" apps/mobile/src/features/meals/Summary.tsx "Registrado. Sua estimativa fica em faixa."
reports "accents and case are ignored" apps/mobile/src/shared/messages.ts "DÉFICIT calórico" ":1:deficit"
reports "accent-free text matches accented term" apps/mobile/src/shared/messages.ts "um deficit" ":1:deficit"
passes "whole word: 'limpar' does not match 'limpa'" apps/mobile/src/shared/messages.ts "Vamos limpar o filtro"
reports "whole expression: 'comida limpa' matches" apps/mobile/src/shared/messages.ts "uma comida limpa" ":1:comida limpa"
passes "whole word: 'culpado' is not 'culpa'" apps/mobile/src/shared/messages.ts "O culpado e outro"
reports "'culpa' alone matches" apps/mobile/src/shared/messages.ts "Sem culpa, ok? Culpa." ":1:culpa"
reports "multi-space expression matches" apps/mobile/src/shared/messages.ts "meta   de  calorias" ":1:meta de calorias"
reports "consent text is scanned" apps/api/config/consents/x.v1.md "Você deveria comer menos" ":1:voce deveria"
reports "locales are scanned" apps/api/config/locales/pt.yml "a: acima do limite" ":1:acima do limite"
reports "API error messages are scanned" apps/api/app/controllers/concerns/error_rendering.rb '"a" => "comida ruim"' ":1:comida ruim"
reports "API error app is scanned" apps/api/lib/api_error_app.rb '"a" => "comida lixo"' ":1:comida lixo"
reports "sub-directories of a scan path are scanned" apps/mobile/src/features/meals/deep/a.ts "comida boa" ":1:comida boa"
passes "test files under a scan path are skipped" apps/mobile/src/features/meals/__tests__/a.test.ts "comida boa"
passes "file outside scan paths is ignored" apps/mobile/src/other.ts "comida boa"

fresh; run
if [ "$CODE" -eq 0 ]; then expect "missing scan paths are nothing to scan" ok; else expect "missing scan paths are nothing to scan" fail; fi

printf '# comentário\n\nTermo Inventado\n' > "$WORK/deny.txt"
fresh; put apps/mobile/src/shared/messages.ts "um termo inventado aqui"; run "$WORK/deny.txt"
if [ "$CODE" -eq 1 ] && echo "$OUT" | grep -qF ":1:termo inventado"; then
  expect "denylist: comments and blanks skipped, terms normalized" ok
else
  expect "denylist: comments and blanks skipped, terms normalized" fail
fi
fresh; put apps/mobile/src/shared/messages.ts "comentário"; run "$WORK/deny.txt"
if [ "$CODE" -eq 0 ]; then expect "denylist: comment line is not a term" ok; else expect "denylist: comment line is not a term" fail; fi

fresh
OUT="$(python3 -I "$CHECK" --root "$WORK/root" --denylist "$WORK/nope.txt" 2>&1)"; CODE=$?
if [ "$CODE" -ne 0 ] && [ "$CODE" -ne 1 ]; then
  expect "missing denylist is an error, not a pass" ok
else
  expect "missing denylist is an error, not a pass" fail
fi

# Termos que o revisor provou passar antes: cada um com um exemplo positivo e um negativo.
M=apps/mobile/src/shared/messages.ts
pair() { # termo-esperado, texto que casa, texto limpo parecido
  reports "denylist catches '$1'" "$M" "$2" ":1:$1"
  passes "denylist spares near-miss of '$1'" "$M" "$3"
}
pair "calorias restantes" "Restam calorias restantes" "Calorias restam registradas"
pair "caloria restante" "Uma caloria restante" "Uma caloria registrada"
pair "limite de calorias" "Seu limite de calorias" "Limite de fotos"
pair "teto de calorias" "O teto de calorias" "O teto do prédio"
pair "comendo demais" "Está comendo demais" "Está comendo bem"
pair "comeu demais" "Hoje você comeu demais" "Hoje você comeu bem"
pair "comeu pouco" "Você comeu pouco" "Você comeu poucos itens"
pair "comendo pouco" "Está comendo pouco" "Está comendo poucos itens"
pair "voce nao deveria" "Você não deveria" "Você não pode ver isso"
pair "secar" "Quer secar rápido" "O secador está ligado"
pair "secando" "Você está secando" "Você está secou"
pair "sem dor sem ganho" "Sem dor sem ganho!" "Sem dor de cabeça"
pair "sem dor, sem ganho" "Sem dor, sem ganho!" "Sem dor de cabeça"
pair "dieta limpa" "Faça dieta limpa" "Dieta registrada"
pair "comer limpo" "Quer comer limpo" "Quer comer bem"
pair "alimento ruim" "Esse alimento ruim" "Esse alimento registrado"
pair "alimento bom" "Um alimento bom" "Um alimento registrado"
pair "refeicao lixo" "Uma refeição lixo" "Uma refeição registrada"
pair "junk food" "Evite junk food" "Evite repetir"
pair "junk" "Que junk" "Um junkyard"
pair "emagrec*" "Para emagrecimento" "Para magreza"
reports "trailing * matches an inflection" "$M" "emagreça já" ":1:emagrec*"

# Lista de exceções: caminho|linha exata|motivo
ALLOW_LINE="Não define meta nem limite de calorias."
printf 'apps/api/config/consents/h.md|%s|aprovado\n' "$ALLOW_LINE" > "$WORK/allow.txt"
fresh; put apps/api/config/consents/h.md "Não define meta nem limite de calorias."; run "$DENY" "$WORK/allow.txt"
if [ "$CODE" -eq 0 ]; then expect "allowlisted line passes" ok; else expect "allowlisted line passes" fail; fi
fresh; put apps/api/config/consents/h.md $'Não define meta nem limite de calorias.\nTem limite de calorias hoje'; run "$DENY" "$WORK/allow.txt"
if [ "$CODE" -eq 1 ] && echo "$OUT" | grep -qF "h.md:2:limite de calorias"; then expect "same term on another line still fails" ok; else expect "same term on another line still fails" fail; fi
fresh; put apps/api/config/consents/other.md "Não define meta nem limite de calorias."; put apps/api/config/consents/h.md "Texto limpo"; run "$DENY" "$WORK/allow.txt"
if [ "$CODE" -eq 1 ] && echo "$OUT" | grep -qF "other.md:1:limite de calorias"; then expect "same line in another file still fails" ok; else expect "same line in another file still fails" fail; fi
fresh; put apps/api/config/consents/h.md "Texto limpo"; run "$DENY" "$WORK/allow.txt"
if [ "$CODE" -eq 1 ] && echo "$OUT" | grep -qF "stale"; then expect "stale allowlist entry is reported" ok; else expect "stale allowlist entry is reported" fail; fi
fresh; put apps/api/config/consents/h.md "NAO define meta nem LIMITE de calorias."; run "$DENY" "$WORK/allow.txt"
if [ "$CODE" -eq 0 ]; then expect "allowlist compares normalized line" ok; else expect "allowlist compares normalized line" fail; fi

fresh; run
if echo "$OUT" | grep -qi "aviso"; then expect "missing scan path warns" ok; else expect "missing scan path warns" fail; fi

echo
echo "$TESTS testes, $FAILS falhas"
[ "$FAILS" -eq 0 ]
