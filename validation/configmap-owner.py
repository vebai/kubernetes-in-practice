#!/usr/bin/env python3
"""Conservative ownership recovery for one previously validated local lab ConfigMap.

Usage: configmap-owner.py current.json canonical.json deployment.json service.json
Refuses adoption unless the exact ConfigMap data matches and both controlling
workload objects bear the existing book.validation/owner annotation.
"""
import json
import sys

MARKER = 'book.validation/owner'
OWNER = 'kubernetes-in-practice'


def check(current, desired, deployment, service):
    metadata = current.get('metadata') or {}
    assert current.get('kind') == 'ConfigMap', 'current object must be a ConfigMap'
    assert metadata.get('name') == 'flask-config', 'unexpected ConfigMap name'
    assert metadata.get('namespace', 'default') == 'default', 'unexpected namespace'
    assert desired.get('kind') == 'ConfigMap', 'canonical object must be a ConfigMap'
    assert (desired.get('metadata') or {}).get('name') == 'flask-config', 'unexpected canonical name'
    current_owner = (metadata.get('annotations') or {}).get(MARKER, '')
    assert not current_owner, 'do not rewrite existing ownership markers'
    assert current.get('data') == desired.get('data'), 'data differs from canonical Chapter 6 ConfigMap'
    assert isinstance(current.get('data'), dict) and current['data'], 'ConfigMap data must be populated'
    for obj, kind in [(deployment, 'Deployment'), (service, 'Service')]:
        md = obj.get('metadata') or {}
        assert obj.get('kind') == kind, f'expected {kind}'
        assert md.get('name') == 'flask-app', f'unexpected {kind} name'
        assert md.get('namespace', 'default') == 'default', f'unexpected {kind} namespace'
        assert (md.get('annotations') or {}).get(MARKER) == OWNER, f'{kind} is not validation-owned'
    return True


def main():
    try:
        args = [json.load(open(p, encoding='utf8')) for p in sys.argv[1:]]
        if len(args) != 4:
            raise ValueError('expected current, canonical, Deployment and Service JSON')
        check(*args)
    except (OSError, ValueError, AssertionError, TypeError, KeyError) as e:
        print(f'[BLOCKED] ConfigMap ownership recovery: {e}', file=sys.stderr)
        return 1
    print('[INFO] Unannotated ConfigMap exactly matches canonical Chapter 6 data; both parent workload objects carry the book validation marker')
    return 0


if __name__ == '__main__':
    sys.exit(main())
