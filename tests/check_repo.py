#!/usr/bin/env python3
"""Offline structural checks: no Docker, kubectl or AWS calls."""
from pathlib import Path
import ast
import re
import sys

ROOT=Path(__file__).resolve().parents[1]
failed=[]
for p in ROOT.rglob('*.py'):
    if '/.' in str(p.relative_to(ROOT)):
        continue
    try: ast.parse(p.read_text(), filename=str(p))
    except Exception as exc: failed.append(f'Python: {p.relative_to(ROOT)}: {exc}')

try:
    import yaml
except ImportError:
    print('PyYAML unavailable: install python3 -m pip install PyYAML for full static checks')
    yaml=None

if yaml:
    for d in (ROOT/'manifests',ROOT/'eks'):
        for p in d.rglob('*.yaml'):
            try:
                contents=list(yaml.safe_load_all(p.read_text()))
                if not contents or not any(isinstance(x,dict) for x in contents):
                    failed.append(f'YAML contains no object: {p.relative_to(ROOT)}')
            except Exception as exc: failed.append(f'YAML: {p.relative_to(ROOT)}: {exc}')
    for p in (ROOT/'helm').glob('*.yaml'):
        try: yaml.safe_load(p.read_text())
        except Exception as exc:failed.append(f'Helm values: {p.relative_to(ROOT)}: {exc}')
    for p in (ROOT/'helm/flask-app').glob('*.yaml'):
        try: yaml.safe_load(p.read_text())
        except Exception as exc:failed.append(f'Helm chart: {p.relative_to(ROOT)}: {exc}')

for p in ROOT.rglob('*.md'):
    for link in re.findall(r'(?<!!)\[[^]]+\]\(([^)]+)\)',p.read_text()):
        link=link.split('#',1)[0]
        if not link or link.startswith(('https://','http://','mailto:','#')):continue
        if not (p.parent/link).exists():failed.append(f'Broken markdown link: {p.relative_to(ROOT)} -> {link}')
for forbidden in ('BOOK-CODE.md','manuscript','extracted paragraphs','publication-status'):
    if forbidden=='BOOK-CODE.md':
        for p in ROOT.rglob(forbidden):failed.append(f'Forbidden file: {p.relative_to(ROOT)}')
if failed:
    print('\n'.join(failed))
    sys.exit(1)
print('Static Python, YAML and Markdown link checks: passed')
