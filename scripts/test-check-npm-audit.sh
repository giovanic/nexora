#!/usr/bin/env bash
# Prova que check_npm_audit.py reprova alerta alto ou crítico sem exceção, exceção vencida,
# relatório com erro e lista malformada, e aprova o que só tem exceção vigente.
# Gera relatórios mínimos em diretório temporário; não roda npm nem toca no repositório.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="$HERE/check_npm_audit.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

TESTS=0
FAILS=0
OUT=""
CODE=0

report() { printf '%s\n' "$1" > "$WORK/report.json"; }
exceptions() { printf '%s\n' "$1" > "$WORK/exceptions.txt"; }
run() { OUT="$(python3 -I "$CHECK" --report "$WORK/report.json" --exceptions "$WORK/exceptions.txt" --today 2026-11-17 2>&1)"; CODE=$?; }

check() { # name, expected code, text the output must contain (optional)
  TESTS=$((TESTS + 1))
  if [ "$CODE" = "$2" ] && { [ -z "${3:-}" ] || printf '%s' "$OUT" | grep -q -- "$3"; }; then
    echo "ok   $1"
  else
    echo "FAIL $1 (código $CODE, esperado $2)"
    echo "$OUT" | sed 's/^/     /'
    FAILS=$((FAILS + 1))
  fi
}

advisory() { # name, severity, ghsa
  printf '{"source": 1, "name": "%s", "severity": "%s", "url": "https://github.com/advisories/%s", "title": "t"}' "$1" "$2" "$3"
}
with_high="{\"auditReportVersion\": 2, \"vulnerabilities\": {
  \"picomatch\": {\"name\": \"picomatch\", \"severity\": \"high\", \"via\": [$(advisory picomatch high GHSA-fc5q-39xc-vjpf)]},
  \"jest-util\": {\"name\": \"jest-util\", \"severity\": \"high\", \"via\": [\"picomatch\"]}}}"
with_two="{\"auditReportVersion\": 2, \"vulnerabilities\": {
  \"picomatch\": {\"name\": \"picomatch\", \"severity\": \"high\", \"via\": [$(advisory picomatch high GHSA-fc5q-39xc-vjpf)]},
  \"tar\": {\"name\": \"tar\", \"severity\": \"critical\", \"via\": [$(advisory tar critical GHSA-aaaa-bbbb-cccc)]}}}"
only_moderate="{\"auditReportVersion\": 2, \"vulnerabilities\": {
  \"esbuild\": {\"name\": \"esbuild\", \"severity\": \"moderate\", \"via\": [$(advisory esbuild moderate GHSA-mmmm-mmmm-mmmm)]}}}"
valid="GHSA-fc5q-39xc-vjpf 2026-12-17 picomatch sem versão corrigida; só em ferramentas de build"

report '{"auditReportVersion": 2, "vulnerabilities": {}}'; exceptions "# vazio"; run
check "relatório sem alertas aprova" 0
report "$only_moderate"; exceptions "# vazio"; run
check "alerta moderado não reprova" 0
report "$with_high"; exceptions "# vazio"; run
check "alerta alto sem exceção reprova" 1 "GHSA-fc5q-39xc-vjpf"
report "$with_high"; exceptions "$valid"; run
check "alerta alto com exceção vigente aprova e avisa" 0 "exceção vigente até 2026-12-17"
report "$with_high"; exceptions "GHSA-fc5q-39xc-vjpf 2026-11-16 venceu ontem"; run
check "exceção vencida reprova" 1 "vencida"
report "$with_high"; exceptions "GHSA-fc5q-39xc-vjpf 2026-11-17 vence hoje"; run
check "exceção vale até o dia da validade" 0
report "$with_two"; exceptions "$valid"; run
check "exceção de um alerta não libera outro" 1 "GHSA-aaaa-bbbb-cccc"
report "$only_moderate"; exceptions "$valid"; run
check "exceção sem uso aprova e pede remoção" 0 "sem uso"
report '{"error": {"code": "ENOTFOUND", "summary": "sem rede"}}'; exceptions "$valid"; run
check "relatório com erro reprova" 1 "ENOTFOUND"
report 'não é json'; exceptions "$valid"; run
check "relatório ilegível reprova" 1
report "$with_high"; exceptions "GHSA-fc5q-39xc-vjpf sem-data motivo"; run
check "exceção sem data reprova" 1 "malformada"
report "$with_high"; exceptions "GHSA-fc5q-39xc-vjpf 2026-12-17"; run
check "exceção sem motivo reprova" 1 "malformada"
report "$with_high"; exceptions "GHSA-fc5q-39xc-vjpf 2027-12-17 prazo longo demais"; run
check "exceção com mais de 90 dias reprova" 1 "90 dias"

echo "$TESTS testes, $FAILS falhas"
[ "$FAILS" -eq 0 ]
