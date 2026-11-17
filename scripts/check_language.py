#!/usr/bin/env python3
"""Confere os textos estáticos contra a lista de linguagem proibida (NFR-SAFETY-002).

Origem da lista: docs/security/HEALTH_DATA_SAFETY.md, seção "Linguagem", em
scripts/language_denylist.txt (um termo por linha, "#" comenta, UTF-8).

Comparação: sem caixa e sem acentos (NFKD, sem marcas combinantes, nos dois
lados), como palavra ou expressão inteira (fronteira de palavra nos dois
extremos; espaços do termo casam com qualquer sequência de espaços). Assim
"limpar" não casa "limpa" e "culpado" não casa "culpa". A busca é por linha,
então uma expressão quebrada em duas linhas não é vista.

Saída: código 0 sem ocorrências; código 1 com "arquivo:linha:termo" por
ocorrência; código 2 para erro de uso (lista ausente). Caminho que ainda não
existe não é erro (avisa em stderr): não há o que varrer. Só Python 3 padrão.

Termo terminando em "*" casa prefixo de palavra ("emagrec*" casa "emagreça").
Sem "*", só a palavra inteira. Prefira formas explícitas; use "*" só com raiz
longa o bastante para não casar outras palavras.

Exceções: scripts/language_allow.txt, linhas "caminho|linha exata|motivo". Um
achado é ignorado só se o arquivo e a linha inteira (normalizada) forem iguais
à entrada. Entrada cuja linha não existe mais é reportada como "stale" (exit 1).
"""
import argparse
import os
import re
import sys
import unicodedata

# Relativos à raiz do repositório. Pasta: varre os arquivos de texto abaixo dela.
SCAN_PATHS = [
    "apps/mobile/src/features/meals",
    "apps/mobile/src/shared/messages.ts",
    "apps/api/config/consents",
    "apps/api/config/locales",
    # Mensagens de erro da API (texto humano por código).
    "apps/api/app/controllers/concerns/error_rendering.rb",
    "apps/api/lib/api_error_app.rb",
]
TEXT_SUFFIXES = {".md", ".ts", ".tsx", ".js", ".jsx", ".rb", ".yml", ".yaml", ".txt", ".json"}
TEST_DIRS = {"__tests__", "__mocks__"}
TEST_NAME = re.compile(r"\.(test|spec)\.[jt]sx?$")


def normalize(text):
    decomposed = unicodedata.normalize("NFKD", text)
    return "".join(c for c in decomposed if not unicodedata.combining(c)).lower()


def load_terms(path):
    terms = []
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if line and not line.startswith("#"):
                terms.append(normalize(line))
    return terms


def compile_term(term):
    prefix = term.endswith("*")
    body = r"\s+".join(re.escape(part) for part in term.rstrip("*").split())
    return re.compile(r"(?<!\w)" + body + (r"\w*" if prefix else r"(?!\w)"))


def load_allow(path):
    """Entradas (arquivo, linha normalizada) -> número da linha na lista."""
    entries = {}
    if not path or not os.path.exists(path):
        return entries
    with open(path, encoding="utf-8") as handle:
        for number, raw in enumerate(handle, 1):
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("|", 2)
            if len(parts) < 3 or not parts[2].strip():
                raise ValueError(f"{path}:{number}: use caminho|linha|motivo")
            entries[(parts[0].strip(), normalize(parts[1]).strip())] = number
    return entries


def is_test_file(name):
    return bool(TEST_NAME.search(name))


def files_under(root, rel):
    full = os.path.join(root, rel)
    if os.path.isfile(full):
        yield rel
        return
    if not os.path.isdir(full):
        return
    for base, dirs, names in os.walk(full):
        dirs[:] = sorted(d for d in dirs if d not in TEST_DIRS)
        for name in sorted(names):
            if os.path.splitext(name)[1] in TEXT_SUFFIXES and not is_test_file(name):
                yield os.path.relpath(os.path.join(base, name), root)


def main(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--root", default=os.path.dirname(here))
    parser.add_argument("--denylist", default=os.path.join(here, "language_denylist.txt"))
    parser.add_argument("--allow", default=os.path.join(here, "language_allow.txt"))
    args = parser.parse_args(argv)

    try:
        terms = load_terms(args.denylist)
    except OSError as error:
        print(f"check_language: não foi possível ler a lista: {error}", file=sys.stderr)
        return 2
    patterns = [(term, compile_term(term)) for term in terms]
    try:
        allow = load_allow(args.allow)
    except (OSError, ValueError) as error:
        print(f"check_language: lista de exceções inválida: {error}", file=sys.stderr)
        return 2
    used = set()

    hits = []
    for rel in SCAN_PATHS:
        if not os.path.exists(os.path.join(args.root, rel)):
            print(f"check_language: aviso: nada a varrer em {rel} (não existe)", file=sys.stderr)
        for path in files_under(args.root, rel):
            with open(os.path.join(args.root, path), encoding="utf-8") as handle:
                for number, line in enumerate(handle, 1):
                    text = normalize(line)
                    key = (path, text.strip())
                    for term, pattern in patterns:
                        if pattern.search(text):
                            if key in allow:
                                used.add(key)
                            else:
                                hits.append(f"{path}:{number}:{term}")
                    if key in allow:
                        used.add(key)

    for (path, _line), number in allow.items():
        if (path, _line) not in used:
            hits.append(f"{args.allow}:{number}:stale (linha de {path} não existe mais)")

    for hit in hits:
        print(hit)
    if hits:
        print(f"check_language: {len(hits)} ocorrência(s) de linguagem proibida", file=sys.stderr)
        return 1
    print("check_language: nenhum termo proibido nos textos estáticos")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
