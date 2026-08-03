#!/usr/bin/env python3
"""Arquiva um relatório HTML em `.reports/`, que o git ignora.

Os relatórios publicados como artifact são fragmentos: sem `<!doctype>`, sem `<html>`,
sem `<head>` — o wrapper vem na publicação. Salvos crus, abrem no navegador com os acentos
quebrados, porque falta o `<meta charset>`. Este script embrulha o fragmento num documento
completo, guarda em `.reports/` com a data no nome, e regenera o índice.

Uso:
    scripts/save-report.py <arquivo.html> --slug <nome-curto> \
        [--title "Título"] [--url <url do artifact>] [--note "uma linha"] [--date AAAA-MM-DD]

O índice fica em `.reports/index.html`; os metadados, em `.reports/index.json`, para que
uma execução futura não precise reinformar o que já foi salvo.
"""
import argparse
import datetime
import html
import json
import os
import re
import shutil
import subprocess

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(REPO, ".reports")

WRAPPER = """<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
{head}
</head>
<body>
{body}
</body>
</html>
"""

INDEX_CSS = """
:root {
  color-scheme: light dark;
  --paper: #f3f4f6; --card: #fff; --ink: #14181d; --ink-soft: #4d5560;
  --ink-faint: #7b838f; --rule: #d9dde3; --accent: #2d5f7c; --code-bg: #eef0f3;
}
@media (prefers-color-scheme: dark) {
  :root {
    --paper: #0e1116; --card: #161b22; --ink: #e4e8ee; --ink-soft: #a7b0bc;
    --ink-faint: #7d8695; --rule: #262d36; --accent: #7db4d6; --code-bg: #10151b;
  }
}
:root[data-theme="dark"] {
  --paper: #0e1116; --card: #161b22; --ink: #e4e8ee; --ink-soft: #a7b0bc;
  --ink-faint: #7d8695; --rule: #262d36; --accent: #7db4d6; --code-bg: #10151b;
}
:root[data-theme="light"] {
  --paper: #f3f4f6; --card: #fff; --ink: #14181d; --ink-soft: #4d5560;
  --ink-faint: #7b838f; --rule: #d9dde3; --accent: #2d5f7c; --code-bg: #eef0f3;
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--paper); color: var(--ink);
  font: 400 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  font-variant-numeric: tabular-nums;
}
.wrap { max-width: 780px; margin: 0 auto; padding: 44px 22px 80px; display: flex; flex-direction: column; gap: 30px; }
h1 { margin: 0; font-size: 1.9rem; font-weight: 650; letter-spacing: -0.02em; text-wrap: balance; }
.eyebrow { margin: 0 0 6px; font-size: 0.72rem; font-weight: 660; letter-spacing: 0.14em; text-transform: uppercase; color: var(--accent); }
p { margin: 0; max-width: 66ch; color: var(--ink-soft); }
ol { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 14px; }
li { background: var(--card); border: 1px solid var(--rule); border-radius: 10px; padding: 16px 18px; display: flex; flex-direction: column; gap: 8px; }
.row { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
.date { font-size: 0.75rem; font-weight: 660; letter-spacing: 0.06em; color: var(--ink-faint); white-space: nowrap; }
.title { font-size: 1.02rem; font-weight: 620; flex: 1; min-width: 200px; }
.title a { color: inherit; text-decoration: none; border-bottom: 1px solid var(--accent); }
.title a:hover { color: var(--accent); }
.note { font-size: 0.9rem; }
.links { display: flex; gap: 14px; flex-wrap: wrap; font-size: 0.82rem; }
.links a { color: var(--accent); }
code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 0.84em; background: var(--code-bg); padding: 0.1em 0.35em; border-radius: 4px; }
footer { border-top: 1px solid var(--rule); padding-top: 18px; color: var(--ink-faint); font-size: 0.85rem; }
"""


def split_fragment(text):
    """Separa o que pertence ao `<head>` (title, style, meta) do resto."""
    if re.search(r"<!doctype|<html\b", text, re.I):
        return None, text  # já é um documento completo
    head_parts = []

    def grab(pattern):
        nonlocal text
        for m in list(re.finditer(pattern, text, re.I | re.S)):
            head_parts.append(m.group(0))
        text = re.sub(pattern, "", text, flags=re.I | re.S)

    grab(r"<title>.*?</title>")
    grab(r"<style\b[^>]*>.*?</style>")
    grab(r"<meta\b[^>]*>")
    return "\n".join(head_parts), text.strip()


def write_index(entries):
    rows = []
    for e in sorted(entries, key=lambda x: (x["date"], x["slug"]), reverse=True):
        links = [f'<a href="{html.escape(e["file"])}">abrir cópia local</a>']
        if e.get("url"):
            links.append(f'<a href="{html.escape(e["url"])}">artifact publicado</a>')
        note = f'<p class="note">{e["note"]}</p>' if e.get("note") else ""
        rows.append(
            f'''    <li>
      <div class="row">
        <span class="date">{html.escape(e["date"])}</span>
        <span class="title"><a href="{html.escape(e["file"])}">{e["title"]}</a></span>
      </div>
      {note}
      <div class="links">{" · ".join(links)}</div>
    </li>'''
        )

    body = f"""<div class="wrap">
  <header>
    <p class="eyebrow">sdk-mobile · histórico local</p>
    <h1>Relatórios de validação e revisão</h1>
    <p>
      Cópias offline dos relatórios publicados, do mais recente para o mais antigo. Esta pasta
      é ignorada pelo git — ela existe para acompanhar o que já foi resolvido sem depender do
      scratchpad de uma sessão. Para adicionar um relatório novo:
      <code>scripts/save-report.py &lt;arquivo.html&gt; --slug &lt;nome&gt;</code>.
    </p>
  </header>
  <ol>
{chr(10).join(rows)}
  </ol>
  <footer>{len(rows)} relatório(s) arquivado(s) em <code>.reports/</code>.</footer>
</div>"""

    with open(os.path.join(DEST, "index.html"), "w") as fh:
        fh.write(WRAPPER.format(
            head=f"<title>Relatórios · sdk-mobile</title>\n<style>{INDEX_CSS}</style>",
            body=body,
        ))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("--slug", required=True)
    ap.add_argument("--title")
    ap.add_argument("--url")
    ap.add_argument("--note")
    ap.add_argument("--date")
    args = ap.parse_args()

    os.makedirs(DEST, exist_ok=True)
    text = open(args.source).read()
    head, body = split_fragment(text)

    date = args.date or datetime.date.fromtimestamp(
        os.path.getmtime(args.source)
    ).isoformat()
    fname = f"{date}-{args.slug}.html"

    if head is None:
        shutil.copyfile(args.source, os.path.join(DEST, fname))
    else:
        with open(os.path.join(DEST, fname), "w") as fh:
            fh.write(WRAPPER.format(head=head, body=body))

    title = args.title
    if not title:
        m = re.search(r"<title>(.*?)</title>", text, re.I | re.S)
        title = m.group(1).strip() if m else args.slug

    index_json = os.path.join(DEST, "index.json")
    entries = json.load(open(index_json)) if os.path.exists(index_json) else []
    entries = [e for e in entries if e["slug"] != args.slug]
    entry = {"slug": args.slug, "date": date, "file": fname, "title": title}
    if args.url:
        entry["url"] = args.url
    if args.note:
        entry["note"] = args.note
    entries.append(entry)

    with open(index_json, "w") as fh:
        json.dump(entries, fh, indent=2, ensure_ascii=False)
    write_index(entries)

    size = os.path.getsize(os.path.join(DEST, fname)) // 1024
    print(f"✅ .reports/{fname}  ({size} KB)")
    print(f"   índice: .reports/index.html  ({len(entries)} relatórios)")

    # Aviso barato que evita o modo de falha óbvio: a pasta deixar de ser ignorada.
    ignored = subprocess.run(
        ["git", "check-ignore", "-q", os.path.join(DEST, fname)], cwd=REPO
    ).returncode == 0
    if not ignored:
        print("⚠️  .reports/ NÃO está sendo ignorada pelo git — confira o .gitignore")


if __name__ == "__main__":
    main()
