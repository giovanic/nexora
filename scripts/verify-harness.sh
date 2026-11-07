#!/usr/bin/env bash
# Verifica o Engineering Harness. Uso: scripts/verify-harness.sh [RAIZ]
# Retorna 0 sem falhas e 1 com falhas. Sem dependências além do Python 3.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$HERE/..}"
exec python3 -I "$HERE/verify_harness.py" "$ROOT" "$HERE/harness-manifest.txt"
