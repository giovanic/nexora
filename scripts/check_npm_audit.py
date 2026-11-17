#!/usr/bin/env python3
"""Reprova alerta alto ou crítico do `npm audit --json` que não tenha exceção vigente.

Substitui `npm audit --audit-level=high` no CI. A exceção é por alerta (GHSA), com data de
validade de até 90 dias e motivo, em scripts/npm_audit_exceptions.txt. Vencida a data, o CI
volta a reprovar sozinho. Política em docs/security/SECURITY.md.
"""
import argparse
import datetime
import json
import re
import sys

BLOCKING = {"high", "critical"}
MAX_DAYS = 90
LINE = re.compile(r"^(GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4})\s+(\d{4}-\d{2}-\d{2})\s+(\S.*)$")
GHSA = re.compile(r"GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}")


def load_exceptions(path, today):
    exceptions, errors = {}, []
    with open(path, encoding="utf-8") as handle:
        for number, raw in enumerate(handle, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            match = LINE.match(line)
            try:
                until = datetime.date.fromisoformat(match.group(2)) if match else None
            except ValueError:
                until = None
            if until is None:
                errors.append(f"{path}:{number}: exceção malformada; formato: GHSA-xxxx-xxxx-xxxx AAAA-MM-DD motivo")
                continue
            if (until - today).days > MAX_DAYS:
                errors.append(f"{path}:{number}: {match.group(1)} com validade acima de {MAX_DAYS} dias")
                continue
            exceptions[match.group(1)] = until
    return exceptions, errors


def blocking_advisories(report):
    found = {}
    for package in report.get("vulnerabilities", {}).values():
        for via in package.get("via", []):
            if isinstance(via, dict) and via.get("severity") in BLOCKING:
                ghsa = GHSA.search(via.get("url", ""))
                key = ghsa.group(0) if ghsa else f"{via.get('name')}: {via.get('title')}"
                found.setdefault(key, set()).add(via.get("name") or package.get("name"))
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", required=True, help="saída de npm audit --json")
    parser.add_argument("--exceptions", required=True)
    parser.add_argument("--today", help="AAAA-MM-DD, para os testes")
    args = parser.parse_args()
    today = datetime.date.fromisoformat(args.today) if args.today else datetime.date.today()

    try:
        with open(args.report, encoding="utf-8") as handle:
            report = json.load(handle)
    except (OSError, ValueError) as error:
        print(f"FALHA: relatório do npm audit ilegível: {error}")
        return 1
    if "error" in report:
        print(f"FALHA: o npm audit não rodou: {report['error'].get('code')} {report['error'].get('summary', '')}")
        return 1

    exceptions, failures = load_exceptions(args.exceptions, today)
    found = blocking_advisories(report)
    for key in sorted(found):
        packages = ", ".join(sorted(found[key]))
        until = exceptions.get(key)
        if until is None:
            failures.append(f"{key} ({packages}) sem exceção")
        elif until < today:
            failures.append(f"{key} ({packages}) com exceção vencida em {until}")
        else:
            print(f"AVISO: {key} ({packages}) ignorado por exceção vigente até {until}")
    for key in sorted(set(exceptions) - set(found)):
        print(f"AVISO: exceção {key} sem uso; remova de {args.exceptions}")

    for failure in failures:
        print(f"FALHA: {failure}")
    if failures:
        return 1
    print("npm audit: nenhum alerta alto ou crítico sem exceção vigente")
    return 0


if __name__ == "__main__":
    sys.exit(main())
