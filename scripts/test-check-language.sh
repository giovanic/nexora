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
run() { OUT="$(python3 -I "$CHECK" --root "$WORK/root" --denylist "${1:-$DENY}" 2>&1)"; CODE=$?; }

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

echo
echo "$TESTS testes, $FAILS falhas"
[ "$FAILS" -eq 0 ]
