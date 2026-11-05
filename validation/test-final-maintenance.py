#!/usr/bin/env python3
"""Offline checks for final validated-repository reconciliation."""
from pathlib import Path
r = Path(__file__).resolve().parent.parent
for fn in ['flask-app/Dockerfile', 'flask-app/versions/v2.1.0/Dockerfile',
           'flask-app/versions/v2.2.0/Dockerfile', 'flask-app/versions/v2.3.0/Dockerfile']:
    t = (r/fn).read_text()
    assert t.count('--no-control-socket') == 1, fn
    print('PASS: Gunicorn control socket disabled:',fn)
assert '--workers' in (r/'flask-app/versions/v2.2.0/Dockerfile').read_text()
assert '--workers' not in (r/'flask-app/versions/v2.3.0/Dockerfile').read_text()
print('PASS: HPA load-test-specific Gunicorn workers not retained in hardened v2.3.0')
s=(r/'validation/aws-live/12-capstone.sh').read_text()
assert 'rollback_flag=--rollback-on-failure' in s and '--atomic --timeout' not in s
assert 'sys.exit(0 if deleted not in' in s
print('PASS: Helm 4 upgrade uses supported rollback flag and quiet Pod polling')
s=(r/'validation/aws-live/10-create-deploy.sh').read_text()
assert 'status" == DEGRADED' not in s and 'status=$status (poll' in s
print('PASS: Metrics Server DEGRADED polls rather than causing immediate stop')
s=(r/'validation/lib.sh').read_text()
assert 'recover_canonical_configmap_owner' in s and 'apply_owned "$PROFILE" default configmap/flask-config' in s
print('PASS: historical ConfigMap owner reconciliation is guarded')
for path in ['docs/VALIDATION-EVIDENCE.md','docs/REPO-BOOK-PATHS.md','validation/apply-repo-docs.py']:
    assert (r/path).is_file(), path
print('FINAL MAINTENANCE STATIC CHECKS: PASS')
