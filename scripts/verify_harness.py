"""Verificador do Engineering Harness. Só biblioteca padrão.

Formatos impostos: ver "Contratos de formato" em docs/roadmap/PHASE_EXECUTION_PROTOCOL.md.
"""
import json
import os
import re
import sys
from urllib.parse import unquote

PHASE_FILES = {
    "PHASE_00_HARNESS.md": ["00"],
    "PHASE_01_FOUNDATION.md": ["01"],
    "PHASE_02_IDENTITY_SECURITY.md": ["02"],
    "PHASE_03_FOOD_AI.md": ["03"],
    "PHASE_04_STRAVA.md": ["04"],
    "PHASE_05_GOALS.md": ["05.1", "05.2"],
    "PHASE_06_GAMIFICATION.md": ["06"],
    "PHASE_07_APPLICATIONS.md": ["07"],
    "PHASE_08_INTELLIGENCE.md": ["08"],
    "PHASE_09_PRODUCTION.md": ["09"],
    "MILESTONE_M1_CLOSED_BETA.md": ["M1"],
}
PHASE_SECTIONS = [
    "Objetivo", "Escopo", "Funcionalidades", "Dependências",
    "Arquivos e módulos esperados", "Critérios de aceite", "Testes", "Riscos",
    "Entregáveis", "Definition of Done", "Estratégia de revisão",
]
ADR_SECTIONS = [
    "Contexto", "Problema", "Alternativas", "Decisão", "Justificativa",
    "Consequências", "Estado da decisão",
]
ADR_STATES = {"Proposta", "Aceita", "Rejeitada", "Substituída"}
STATES = {
    "Não iniciada", "Em planejamento", "Em desenvolvimento",
    "Em revisão", "Bloqueada", "Concluída",
}
LINES = ["00", "01", "02", "03", "04", "05", "05.1", "05.2", "06", "07", "08", "09", "M1"]
EMPTY = {"", "—", "–", "-"}
FORBIDDEN_AGENT_TOOLS = {"Edit", "MultiEdit", "Write", "NotebookEdit", "*"}
SCOPE_PATHS = ["apps", "packages", "docker-compose.yml", "Gemfile", "package.json"]
SCOPE_BLOCKING_STATES = {"Não iniciada", "Em planejamento"}
REQUIRED_DENY = {"Read(**/.env)", "Read(**/.env.*)"}
ACCEPTED_GAP = r"Lacuna aceita em \d{4}-\d{2}-\d{2}"
PLACEHOLDER_EXEMPT_NAMES = {"PHASE_TEMPLATE.md", "TEMPLATE.md", "MASTER_PROMPT.md"}
MIN_CONTENT = 300

REQ_ID = r"(?:FR|NFR)-[A-Z][A-Z0-9]*-\d{3}"
AC_ID = r"AC-(?:\d{2}(?:\.\d)?|M\d)-\d{2}"


class Verifier:
    def __init__(self, root, manifest):
        self.root = root
        self.manifest = manifest
        self.failures = []

    def fail(self, check, path, reason):
        self.failures.append(f"FALHA {check}: {path}: {reason}")

    def path(self, rel):
        return os.path.join(self.root, rel)

    def read(self, rel):
        """Texto com fins de linha normalizados, ou None se não existir."""
        try:
            with open(self.path(rel), encoding="utf-8", newline="") as f:
                return f.read().replace("\r\n", "\n")
        except (OSError, UnicodeDecodeError):
            return None

    def markdown_files(self):
        found = []
        for name in ("CLAUDE.md", "README.md"):
            if os.path.isfile(self.path(name)):
                found.append(name)
        for top in ("docs", ".claude"):
            for base, dirs, files in os.walk(self.path(top)):
                dirs[:] = [d for d in dirs if d != "worktrees"]
                for name in files:
                    if name.endswith(".md"):
                        found.append(os.path.relpath(os.path.join(base, name), self.root))
        return sorted(found)

    # Checks

    def check_required(self):
        try:
            with open(self.manifest, encoding="utf-8") as f:
                entries = [l.strip() for l in f if l.strip() and not l.startswith("#")]
        except OSError:
            self.fail("required", self.manifest, "manifesto não encontrado")
            return
        for rel in entries:
            text = self.read(rel)
            if text is None:
                self.fail("required", rel, "arquivo ausente")
            elif rel.endswith(".md") and len(re.sub(r"\s", "", text)) < MIN_CONTENT:
                self.fail("required", rel, f"menos de {MIN_CONTENT} caracteres de conteúdo")

    def check_claude_md(self):
        text = self.read("CLAUDE.md")
        if text is not None and len(text.splitlines()) >= 200:
            self.fail("claude-md", "CLAUDE.md", "precisa ter menos de 200 linhas")

    def check_frontmatter(self):
        agents = self.path(".claude/agents")
        for name in sorted(os.listdir(agents)) if os.path.isdir(agents) else []:
            if name.endswith(".md"):
                self._check_agent(f".claude/agents/{name}", name[:-3])
        skills = self.path(".claude/skills")
        for name in sorted(os.listdir(skills)) if os.path.isdir(skills) else []:
            rel = f".claude/skills/{name}/SKILL.md"
            if os.path.isfile(self.path(rel)):
                self._check_skill(rel, name)
        rules = self.path(".claude/rules")
        for name in sorted(os.listdir(rules)) if os.path.isdir(rules) else []:
            if name.endswith(".md"):
                self._check_rule(f".claude/rules/{name}")

    def _check_agent(self, rel, stem):
        meta = parse_frontmatter(self.read(rel) or "")
        if meta is None:
            self.fail("frontmatter", rel, "frontmatter ausente")
            return
        if meta.get("name") != stem:
            self.fail("frontmatter", rel, f"name deve ser {stem}")
        if not meta.get("description"):
            self.fail("frontmatter", rel, "description ausente")
        tools = meta.get("tools")
        if not tools:
            self.fail("frontmatter", rel, "tools ausente: agent herdaria todas as ferramentas")
        else:
            names = tools if isinstance(tools, list) else [t.strip() for t in tools.split(",")]
            names = [n.strip().strip("\"'") for n in names]
            bad = FORBIDDEN_AGENT_TOOLS.intersection(names)
            if bad:
                self.fail("frontmatter", rel, f"revisor não pode ter {', '.join(sorted(bad))}")

    def _check_skill(self, rel, directory):
        meta = parse_frontmatter(self.read(rel) or "")
        if meta is None:
            self.fail("frontmatter", rel, "frontmatter ausente")
            return
        if meta.get("name") != directory:
            self.fail("frontmatter", rel, f"name deve ser {directory}")
        if not meta.get("description"):
            self.fail("frontmatter", rel, "description ausente")

    def _check_rule(self, rel):
        meta = parse_frontmatter(self.read(rel) or "")
        if meta is not None and "paths" in meta and not meta["paths"]:
            self.fail("frontmatter", rel, "paths vazio")

    def check_phase_sections(self):
        for name, lines in PHASE_FILES.items():
            rel = f"docs/roadmap/phases/{name}"
            text = self.read(rel)
            if text is None:
                continue
            headings = re.findall(r"^## (.+?)\s*$", strip_code(text), re.M)
            position = -1
            for section in PHASE_SECTIONS:
                if section not in headings:
                    self.fail("phase-sections", rel, f"seção ausente: {section}")
                    continue
                index = headings.index(section)
                if index < position:
                    self.fail("phase-sections", rel, f"seção fora de ordem: {section}")
                position = max(position, index)
            criteria = section_text(text, "Critérios de aceite")
            for line in lines:
                if not re.search(r"AC-%s-\d{2}" % re.escape(line), criteria):
                    self.fail("phase-sections", rel, f"sem critério de aceite AC-{line}-NN")
            seen = set()
            for item in criteria.splitlines():
                found = re.match(r"\s*-\s+`?(%s)" % AC_ID, item)
                if not found:
                    continue
                if found.group(1) in seen:
                    self.fail("phase-sections", rel, f"critério repetido: {found.group(1)}")
                seen.add(found.group(1))
                if not re.search(r"comprovad[oa]s? por", item, re.I):
                    self.fail("phase-sections", rel, f"{found.group(1)} sem forma de comprovação")

    def check_links(self):
        for rel in self.markdown_files():
            if os.path.basename(rel) == "MASTER_PROMPT.md":
                continue
            base = os.path.dirname(self.path(rel))
            for target in re.findall(r"\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", strip_code(self.read(rel) or "")):
                if re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target) or target.startswith("#"):
                    continue
                clean = unquote(target.split("#", 1)[0])
                if clean and not os.path.exists(os.path.join(base, clean)):
                    self.fail("links", rel, f"link quebrado: {target}")

    def check_traceability(self):
        reqs_rel = "docs/product/FUNCTIONAL_REQUIREMENTS.md"
        reqs_text = self.read(reqs_rel)
        if reqs_text is None:
            return
        defined = re.findall(r"^\|\s*(%s)\s*\|" % REQ_ID, reqs_text, re.M)
        for req in sorted({r for r in defined if defined.count(r) > 1}):
            self.fail("traceability", reqs_rel, f"requisito definido mais de uma vez: {req}")
        defined = set(defined)

        cited = set()
        criteria = set()
        cited_by_line = {}
        for name in PHASE_FILES:
            rel = f"docs/roadmap/phases/{name}"
            text = self.read(rel)
            if text is None:
                continue
            refs = set(re.findall(r"\b%s\b" % REQ_ID, text))
            for ref in sorted(refs - defined):
                self.fail("traceability", rel, f"requisito inexistente: {ref}")
            cited |= refs
            found = set(re.findall(r"\b%s" % AC_ID, section_text(text, "Critérios de aceite")))
            criteria |= found
            for line in PHASE_FILES[name]:
                cited_by_line[line] = refs
        for req in sorted(defined - cited):
            self.fail("traceability", reqs_rel, f"requisito sem fase: {req}")

        matrix_rel = "docs/roadmap/TRACEABILITY.md"
        matrix_text = self.read(matrix_rel)
        if matrix_text is None:
            return
        rows = [r for r in table_rows(matrix_text) if re.fullmatch(REQ_ID, r[0])]
        states = {row[0]: row[1] for row in self._status_rows() if len(row) > 1}
        seen = set()
        for row in rows:
            if len(row) != 6:
                self.fail("traceability", matrix_rel, f"linha com {len(row)} colunas: {row[0]}")
                continue
            req, phase, adr, impl, test, accept = row
            if req in seen:
                self.fail("traceability", matrix_rel, f"linha repetida: {req}")
            seen.add(req)
            self._check_matrix_adr(matrix_rel, req, adr)
            if req not in defined:
                self.fail("traceability", matrix_rel, f"requisito inexistente: {req}")
            if phase not in LINES:
                self.fail("traceability", matrix_rel, f"fase inválida em {req}: {phase}")
            accepted = re.findall(r"\b%s" % AC_ID, accept)
            if not accepted:
                self.fail("traceability", matrix_rel, f"sem critério de aceite: {req}")
            for item in accepted:
                if item not in criteria:
                    self.fail("traceability", matrix_rel, f"critério inexistente em {req}: {item}")
            if phase in LINES and phase != "05":
                if req not in cited_by_line.get(phase, set()):
                    self.fail("traceability", matrix_rel, f"documento da fase {phase} não cita {req}")
                if accepted and not any(a.startswith(f"AC-{phase}-") for a in accepted):
                    self.fail("traceability", matrix_rel, f"critério não pertence à fase {phase}: {req}")
            if states.get(phase) == "Concluída" and phase != "00":
                if impl in EMPTY or test in EMPTY:
                    self.fail("traceability", matrix_rel, f"fase {phase} concluída sem implementação e teste: {req}")
                else:
                    self._check_matrix_cell(matrix_rel, req, impl)
                    self._check_matrix_cell(matrix_rel, req, test)
        for req in sorted(defined - seen):
            self.fail("traceability", matrix_rel, f"requisito fora da matriz: {req}")

    def _check_matrix_adr(self, rel, req, cell):
        directory = self.path("docs/architecture/decisions")
        names = os.listdir(directory) if os.path.isdir(directory) else []
        for number in re.findall(r"\b\d{4}\b", cell):
            if not any(name.startswith(f"{number}-") for name in names):
                self.fail("traceability", rel, f"ADR inexistente em {req}: {number}")

    def _check_matrix_cell(self, rel, req, cell):
        """Célula de fase concluída: caminhos existentes e, se houver, lacuna aceita datada."""
        text = re.sub(ACCEPTED_GAP, "", cell).strip(" .,;")
        if not text:
            return
        for entry in re.split(r"[,;]", text.replace("`", "")):
            entry = re.sub(r":\d+(-\d+)?$", "", entry.strip().rstrip(".")).strip()
            if entry and not os.path.exists(self.path(entry)):
                self.fail("traceability", rel, f"caminho inexistente em {req}: {entry}")

    def check_adr(self):
        directory = self.path("docs/architecture/decisions")
        names = sorted(os.listdir(directory)) if os.path.isdir(directory) else []
        for name in names:
            if not re.match(r"\d{4}-.+\.md$", name):
                continue
            rel = f"docs/architecture/decisions/{name}"
            text = self.read(rel) or ""
            headings = re.findall(r"^## (.+?)\s*$", strip_code(text), re.M)
            for section in ADR_SECTIONS:
                if section not in headings:
                    self.fail("adr", rel, f"seção ausente: {section}")
            state = section_text(text, "Estado da decisão").strip().split("\n")[0].strip()
            if "Estado da decisão" in headings and state not in ADR_STATES:
                self.fail("adr", rel, f"estado inválido: {state or 'vazio'}")

    def _status_rows(self):
        text = self.read("docs/roadmap/STATUS.md") or ""
        return [r for r in table_rows(section_text(text, "Estado atual")) if r[0] != "Linha"]

    def check_status(self):
        rel = "docs/roadmap/STATUS.md"
        text = self.read(rel)
        if text is None:
            return
        rows = self._status_rows()
        current = {}
        for row in rows:
            if len(row) != 4:
                self.fail("status", rel, f"linha com {len(row)} colunas: {row[0]}")
                continue
            line, state, _since, evidence = row
            current[line] = state
            if line not in LINES:
                self.fail("status", rel, f"linha desconhecida: {line}")
            if state not in STATES:
                self.fail("status", rel, f"estado inválido em {line}: {state}")
            if state == "Concluída":
                if evidence in EMPTY:
                    self.fail("status", rel, f"{line} concluída sem evidência")
                report = "M1_REPORT.md" if line == "M1" else f"PHASE_{line}_REPORT.md"
                if line != "05" and not os.path.isfile(self.path(f"docs/roadmap/reports/{report}")):
                    self.fail("status", rel, f"{line} concluída sem relatório {report}")
        for line in LINES:
            if line not in current:
                self.fail("status", rel, f"linha ausente: {line}")

        active = [l for l, s in current.items() if s == "Em desenvolvimento" and l != "05"]
        if len(active) > 1:
            self.fail("status", rel, f"mais de uma linha em desenvolvimento: {', '.join(active)}")
        if current.get("05") == "Concluída" and not (
            current.get("05.1") == "Concluída" and current.get("05.2") == "Concluída"
        ):
            self.fail("status", rel, "05 concluída com etapa em aberto")
        if current.get("05.1") == "Concluída" and current.get("05.2") == "Concluída" and current.get("05") != "Concluída":
            self.fail("status", rel, "05.1 e 05.2 etapas concluídas, mas 05 não")

        last = {}
        log = [r for r in table_rows(section_text(text, "Registro de transições")) if r[0] != "Data"]
        for row in log:
            if len(row) != 5:
                self.fail("status", rel, f"transição com {len(row)} colunas: {row[0]}")
                continue
            date, line, origin, target, evidence = row
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
                self.fail("status", rel, f"data inválida: {date}")
            if line not in LINES:
                self.fail("status", rel, f"linha desconhecida na transição: {line}")
            for state in (origin, target):
                if state not in STATES:
                    self.fail("status", rel, f"estado inválido na transição: {state}")
            if evidence in EMPTY:
                self.fail("status", rel, f"transição de {line} sem evidência")
            if origin != last.get(line, "Não iniciada"):
                self.fail("status", rel, f"transição descontínua em {line}: {origin} → {target}")
            if target == "Concluída" and origin != "Em revisão" and line != "05":
                self.fail("status", rel, f"{line} só pode ser concluída a partir de em revisão")
            last[line] = target
        for line, state in current.items():
            expected = last.get(line, "Não iniciada")
            if state != expected:
                self.fail("status", rel, f"{line} está {state}, mas o registro indica {expected}")

    def check_placeholder(self):
        for rel in self.markdown_files():
            normalized = rel.replace(os.sep, "/")
            if os.path.basename(rel) in PLACEHOLDER_EXEMPT_NAMES or normalized.startswith("docs/superpowers/"):
                continue
            found = set(re.findall(r"\b(TBD|FIXME|TODO(?=\s*[:(]|\s*$))", strip_code(self.read(rel) or ""), re.M))
            if found:
                self.fail("placeholder", rel, f"texto inacabado: {', '.join(sorted(found))}")

    def check_scope(self):
        states = {row[0]: row[1] for row in self._status_rows() if len(row) > 1}
        if states.get("01") not in SCOPE_BLOCKING_STATES:
            return
        for rel in SCOPE_PATHS:
            if os.path.exists(self.path(rel)):
                self.fail("scope", rel, "código de produto antes de a Fase 01 entrar em desenvolvimento")

    def check_settings(self):
        rel = ".claude/settings.json"
        text = self.read(rel)
        if text is None:
            return
        try:
            data = json.loads(text)
        except ValueError as error:
            self.fail("settings", rel, f"JSON inválido: {error}")
            return
        if not isinstance(data, dict):
            self.fail("settings", rel, "precisa ser um objeto JSON")
            return
        plugins = data.get("enabledPlugins")
        if not isinstance(plugins, dict) or plugins.get("superpowers@claude-plugins-official") is not True:
            self.fail("settings", rel, "superpowers@claude-plugins-official não habilitado")
        permissions = data.get("permissions")
        deny = permissions.get("deny", []) if isinstance(permissions, dict) else []
        for rule in sorted(REQUIRED_DENY - set(deny)):
            self.fail("settings", rel, f"regra deny ausente: {rule}")

    def run(self):
        for check in (
            self.check_required, self.check_claude_md, self.check_frontmatter,
            self.check_phase_sections, self.check_links, self.check_traceability,
            self.check_adr, self.check_status, self.check_placeholder,
            self.check_scope, self.check_settings,
        ):
            check()
        return self.failures


def strip_fences(text):
    """Remove blocos de código, inclusive os indentados em listas."""
    return re.sub(r"^[ \t]*(```|~~~).*?^[ \t]*\1[^\n]*$", "", text, flags=re.M | re.S)


def strip_code(text):
    """Remove blocos de código e trechos entre crases."""
    return re.sub(r"`[^`\n]*`", "", strip_fences(text))


def section_text(text, heading):
    """Conteúdo de uma seção ##, até o próximo ## fora de bloco de código."""
    text = strip_fences(text)
    match = re.search(r"^## %s\s*$" % re.escape(heading), text, re.M)
    if not match:
        return ""
    rest = text[match.end():]
    following = re.search(r"^## ", rest, re.M)
    return rest[: following.start()] if following else rest


def table_rows(text):
    """Linhas de tabela Markdown, sem a linha separadora."""
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("|") or not line.endswith("|"):
            continue
        cells = [c.strip() for c in line[1:-1].split("|")]
        if all(re.fullmatch(r":?-+:?", c) for c in cells):
            continue
        rows.append(cells)
    return rows


def parse_frontmatter(text):
    """Chaves de primeiro nível e listas simples. None se não houver bloco."""
    match = re.match(r"---\n(.*?)\n?---\s*(\n|$)", text, re.S)
    if not match:
        return None
    meta = {}
    key = None
    for line in match.group(1).split("\n"):
        item = re.match(r"\s+-\s+(.*)$", line)
        if item and key:
            if not isinstance(meta[key], list):
                meta[key] = []
            meta[key].append(item.group(1).strip().strip("\"'"))
            continue
        pair = re.match(r"([A-Za-z_-]+):\s*(.*)$", line)
        if pair:
            key = pair.group(1)
            value = pair.group(2).strip()
            if value.startswith("[") and value.endswith("]"):
                meta[key] = [v.strip().strip("\"'") for v in value[1:-1].split(",") if v.strip()]
            else:
                meta[key] = value.strip("\"'")
    return meta


def main():
    root, manifest = sys.argv[1], sys.argv[2]
    failures = Verifier(root, manifest).run()
    for failure in failures:
        print(failure)
    if failures:
        print(f"Harness reprovado: {len(failures)} falha(s).")
        return 1
    print("Harness aprovado: nenhuma falha.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
