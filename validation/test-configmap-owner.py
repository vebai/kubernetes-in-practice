#!/usr/bin/env python3
"""Offline regressions for narrow Chapter 6/8 ownership-marker recovery."""
from importlib.machinery import SourceFileLoader
from pathlib import Path
from copy import deepcopy

mod = SourceFileLoader('configmap_owner', str(Path(__file__).with_name('configmap-owner.py'))).load_module()
owner = {'book.validation/owner': 'kubernetes-in-practice'}
base = {'kind': 'ConfigMap', 'metadata': {'name': 'flask-config', 'namespace': 'default', 'annotations': {}}, 'data': {'APP_MESSAGE': 'Hi', 'STARTUP_DELAY_SECONDS': '0'}}
parents = [
    {'kind': 'Deployment', 'metadata': {'name': 'flask-app', 'namespace': 'default', 'annotations': owner}},
    {'kind': 'Service', 'metadata': {'name': 'flask-app', 'namespace': 'default', 'annotations': owner}},
]


def expect(case, valid, mutate):
    objs = [deepcopy(base), deepcopy(base), *deepcopy(parents)]
    mutate(objs)
    try:
        mod.check(*objs)
    except AssertionError:
        if valid:
            raise AssertionError(f'{case}: unexpectedly rejected')
    else:
        if not valid:
            raise AssertionError(f'{case}: unexpectedly adopted unsafe object')
    print('PASS:', case)


expect('canonical old ConfigMap marker may be restored', True, lambda a: None)
expect('modified ConfigMap data refused', False, lambda a: a[0]['data'].update(APP_MESSAGE='Other'))
expect('missing canonical data refused', False, lambda a: a[0].pop('data'))
expect('other ConfigMap name refused', False, lambda a: a[0]['metadata'].update(name='unknown'))
expect('other namespace refused', False, lambda a: a[0]['metadata'].update(namespace='kube-system'))
expect('existing foreign marker refused', False, lambda a: a[0]['metadata'].update(annotations={'book.validation/owner':'someone-else'}))
expect('existing same marker not migrated', False, lambda a: a[0]['metadata'].update(annotations=owner))
expect('unmarked Deployment refused', False, lambda a: a[2]['metadata'].update(annotations={}))
expect('unmarked Service refused', False, lambda a: a[3]['metadata'].update(annotations={}))
expect('wrong Service identity refused', False, lambda a: a[3]['metadata'].update(name='not-ours'))
expect('wrong Deployment kind refused', False, lambda a: a[2].update(kind='Pod'))
print('CONFIGMAP OWNERSHIP REGRESSION TESTS: 11 PASSED')
