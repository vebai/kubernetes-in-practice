#!/usr/bin/env python3
"""Fail-fast semantic checks against the repository's actual Kubernetes YAML.
Not a substitute for cluster verification. Requires PyYAML.
"""
from pathlib import Path
import sys
import yaml

ROOT = Path(__file__).resolve().parents[1]
passed = []
def objects(rel):
    p=ROOT/rel
    return [x for x in yaml.safe_load_all(p.read_text()) if x is not None]
def one(rel):
    x=objects(rel)
    assert len(x)==1, f'{rel}: expected one object, got {len(x)}'
    return x[0]
def test(name, flag):
    assert flag, f'FAIL: {name}'
    print('PASS:', name)
    passed.append(name)
def ctr(deploy): return deploy['spec']['template']['spec']['containers'][0]
def labels(deploy): return deploy['spec']['template']['metadata']['labels']
def selector(deploy): return deploy['spec']['selector']['matchLabels']
def matches(small,big): return all(big.get(k)==v for k,v in small.items())
def cm_refs(deploy):
    return {e['valueFrom']['configMapKeyRef']['key'] for e in ctr(deploy).get('env',[]) if 'configMapKeyRef' in e.get('valueFrom',{})}

d2=one('manifests/chapter-02/flask-pod.yaml')
test('Ch02 has local Pod image', d2['kind']=='Pod' and d2['spec']['containers'][0]['image']=='flask-app:v1.0.0' and d2['spec']['containers'][0]['imagePullPolicy']=='Never')
d3=one('manifests/chapter-03/flask-deployment.yaml')
test('Ch03 replicas and matching labels', d3['kind']=='Deployment' and d3['spec']['replicas']==3 and matches(selector(d3),labels(d3)))
s4=one('manifests/chapter-04/flask-service.yaml')
test('Ch04 Service selects actual Pod',matches(s4['spec']['selector'],labels(d3)) and s4['spec']['ports'][0]['targetPort']=='http')
c5=one('manifests/chapter-05/flask-config.yaml')
d5=one('manifests/chapter-05/flask-deployment-configured.yaml')
test('Ch05 configuration key exists',cm_refs(d5).issubset(c5['data'].keys()) and 'APP_MESSAGE' in cm_refs(d5))
c6=one('manifests/chapter-06/flask-config.yaml')
d6=one('manifests/chapter-06/flask-deployment.yaml')
h6=one('manifests/chapter-06/hpa.yaml')
test('Ch06 version and ConfigMap align',ctr(d6)['image']=='flask-app:v2.2.0' and cm_refs(d6).issubset(c6['data'].keys()))
test('Ch06 three probes cover intended endpoints',ctr(d6)['startupProbe']['httpGet']['path']=='/readyz' and ctr(d6)['readinessProbe']['httpGet']['path']=='/readyz' and ctr(d6)['livenessProbe']['httpGet']['path']=='/healthz')
test('Ch06 HPA targets correct Deployment',h6['spec']['scaleTargetRef']['name']==d6['metadata']['name'] and h6['spec']['maxReplicas']>h6['spec']['minReplicas'])
ns7=one('manifests/chapter-07/namespace.yaml')
d7=one('manifests/chapter-07/deployment-secure.yaml')
p7=d7['spec']['template']['spec']
security=ctr(d7)['securityContext']
test('Ch07 restricted Namespace and image hardening',ns7['metadata']['labels']['pod-security.kubernetes.io/enforce']=='restricted' and p7['securityContext']['runAsNonRoot'] and p7['securityContext']['seccompProfile']['type']=='RuntimeDefault' and security['readOnlyRootFilesystem'] and security['allowPrivilegeEscalation'] is False and 'ALL' in security['capabilities']['drop'])
for rel in ['manifests/chapter-07/default-deny-ingress.yaml','manifests/chapter-07/allow-frontend.yaml']:
    test(rel+' uses correct NetworkPolicy API',one(rel)['apiVersion']=='networking.k8s.io/v1')
allow=one('manifests/chapter-07/allow-frontend.yaml')
a_client=one('manifests/chapter-07/test-client-allowed.yaml')
d_client=one('manifests/chapter-07/test-client-denied.yaml')
test('Ch07 allow rule matches only intended client',allow['spec']['ingress'][0]['from'][0]['podSelector']['matchLabels']==a_client['metadata']['labels'] and d_client['metadata'].get('labels',{}).get('access')!='frontend')
test('Ch07 policy selects secured Flask Pod',matches(allow['spec']['podSelector']['matchLabels'],labels(d7)))
values=one('helm/values-development.yaml')
chart=one('helm/flask-app/Chart.yaml')
test('Ch09 chart and development image versions align',chart['appVersion']==values['image']['tag']=='v2.3.0' and values['image']['pullPolicy']=='Never')
eks=one('eks/cluster.yaml')
eksvalues=one('eks/values-eks.yaml')
capstone=one('eks/values-capstone.yaml')
test('Ch10 EKS baseline is opt-in Auto Mode in eu-west-2',eks['metadata']['name']=='flask-eks' and eks['metadata']['region']=='eu-west-2' and eks['metadata']['version']=='1.36' and eks['autoModeConfig']['enabled'] is True)
test('Ch10 EKS source retains required registry placeholder',eksvalues['image']['repository'].startswith('REPLACE_WITH_ECR_REGISTRY/') and eksvalues['ingress']['enabled'])
test('Ch12 capstone has availability and spread settings',capstone['autoscaling']['minReplicas']>=3 and capstone['pdb']['minAvailable']>=2 and capstone['topologySpread']['enabled'])
for version in ['v2.1.0','v2.2.0','v2.3.0']:
    p=ROOT/'flask-app/versions'/version
    test('Source image variant '+version,all((p/name).exists() for name in ('Dockerfile','requirements.txt','app.py')))
print(f'\nSEMANTIC STATIC CHECKS: {len(passed)} PASSED. LIVE RUNTIME NOT YET TESTED.')
