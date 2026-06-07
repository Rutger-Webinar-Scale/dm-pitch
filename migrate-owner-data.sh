#!/bin/bash
# One-time: import dmps-state-backup.json into Supabase under Rutger's owner profile.
# Run AFTER rutger.kreulen@gmail.com has signed up in the app.
# Keys fetched at runtime via supabase CLI, never printed.
set -e
REF="vpytvszdaepvaaclwuao"
export URL="https://$REF.supabase.co"
KEYS_JSON=$(supabase projects api-keys --project-ref "$REF" -o json 2>/dev/null)
export SERVICE_KEY=$(echo "$KEYS_JSON" | python3 -c "import json,sys;ks=json.load(sys.stdin);print(next(k['api_key'] for k in ks if k.get('name')=='service_role'))")

python3 <<'PY'
import json, os, urllib.request

URL = os.environ['URL']; SK = os.environ['SERVICE_KEY']
def req(path, method='GET', data=None):
    r = urllib.request.Request(URL+path, method=method,
        data=json.dumps(data).encode() if data is not None else None,
        headers={'apikey':SK, 'Authorization':'Bearer '+SK,
                 'Content-Type':'application/json', 'Prefer':'return=representation,resolution=merge-duplicates'})
    try:
        with urllib.request.urlopen(r) as resp:
            b = resp.read()
            return resp.status, json.loads(b) if b else None
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b'null')

# 1. find Rutger's owner profile (either email)
s, profs = req("/rest/v1/profiles?email=in.(rutger%40webinar-scale.com,rutger.kreulen%40gmail.com)&select=id,role")
if s!=200 or not profs:
    print("STOP: geen profiel gevonden — eerst aanmelden in de app."); raise SystemExit(1)
if profs[0]['role']!='owner':
    print("STOP: profiel bestaat maar rol is", profs[0]['role']); raise SystemExit(1)
uid = profs[0]['id']
print("owner profile:", uid)

old = json.load(open('/Users/rutgerkreulen/dm-pitch/dmps-state-backup.json'))

# 2. leads (skip ids that already exist)
s, existing = req("/rest/v1/leads?select=id")
have = {r['id'] for r in (existing or [])}
rows = [{'id':l['id'], 'setter_id':uid, 'data':l} for l in old['leads'] if l.get('id') and l['id'] not in have]
added = 0
for i in range(0, len(rows), 100):
    s, r = req("/rest/v1/leads", "POST", rows[i:i+100])
    if s not in (200,201): print("lead batch error:", s, str(r)[:200]); raise SystemExit(1)
    added += len(rows[i:i+100])
print(f"leads: {added} geimporteerd, {len(old['leads'])-len(rows)} overgeslagen (bestonden al)")

# 3. shared state (merge-duplicates upsert)
shared = [
    {'key':'scripts',    'value':old.get('scripts', {'nl':{},'en':{}})},
    {'key':'goal',       'value':old.get('goal', 30)},
    {'key':'abVariants', 'value':old.get('abVariants', ['A','B'])},
]
s, r = req("/rest/v1/shared_state", "POST", shared)
print("shared_state:", s)

# 4. Rutger's prefs
s, r = req("/rest/v1/user_state", "POST", [{'user_id':uid, 'data':{
    'lang': old.get('lang','nl'),
    'accounts': old.get('accounts',['rutgerkreulen','rutger.kreulen']),
    'activeAccount': old.get('activeAccount','all'),
}}])
print("user_state:", s)
print("\nKLAAR — herlaad de app.")
PY
