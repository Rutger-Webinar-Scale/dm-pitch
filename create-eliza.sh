#!/bin/bash
# Create setter account for Eliza de Graaf + reassign open (un-approached) leads to her.
# Keys fetched at runtime via supabase CLI, never printed.
set -e
REF="vpytvszdaepvaaclwuao"
export URL="https://$REF.supabase.co"
KEYS_JSON=$(supabase projects api-keys --project-ref "$REF" -o json 2>/dev/null)
export SERVICE_KEY=$(echo "$KEYS_JSON" | python3 -c "import json,sys;ks=json.load(sys.stdin);print(next(k['api_key'] for k in ks if k.get('name')=='service_role'))")
export ELIZA_PASS=$(openssl rand -base64 18 | tr -d '/+=' | head -c 14)

python3 <<'PY'
import json, os, urllib.request

URL=os.environ['URL']; SK=os.environ['SERVICE_KEY']; PASS=os.environ['ELIZA_PASS']
def req(path, method='GET', data=None):
    r = urllib.request.Request(URL+path, method=method,
        data=json.dumps(data).encode() if data is not None else None,
        headers={'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json','Prefer':'return=representation'})
    try:
        with urllib.request.urlopen(r) as resp:
            b=resp.read(); return resp.status, json.loads(b) if b else None
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b'null')

EMAIL='edegraaf.edg@gmail.com'

# 1. bestaat ze al?
s, users = req(f"/auth/v1/admin/users?page=1&per_page=100")
existing = next((u for u in (users.get('users',[]) if isinstance(users,dict) else []) if u.get('email','').lower()==EMAIL), None)
if existing:
    uid = existing['id']; print('account bestond al:', uid)
else:
    s, u = req('/auth/v1/admin/users','POST',{
        'email':EMAIL,'password':PASS,'email_confirm':True,
        'user_metadata':{'name':'Eliza de Graaf'}})
    if s not in (200,201): print('FOUT user create:', s, str(u)[:200]); raise SystemExit(1)
    uid = u['id']; print('account aangemaakt:', uid)
    print('TIJDELIJK WACHTWOORD:', PASS)

# 2. profiel check (trigger)
import time
for _ in range(6):
    s, p = req(f"/rest/v1/profiles?id=eq.{uid}&select=name,role")
    if s==200 and p: break
    time.sleep(0.7)
print('profiel:', p[0] if p else 'NIET GEVONDEN')

# 3. haar IG-accounts instellen
s, _ = req('/rest/v1/user_state','POST',[{'user_id':uid,'data':{
    'lang':'nl','accounts':['rutgerkreulen','rutger.kreulen'],'activeAccount':'all'}}])
print('user_state (IG-accounts rutgerkreulen + rutger.kreulen):', s)

# 4. open leads (geen eerste DM gehad, niet afgesloten) -> Eliza
s, leads = req('/rest/v1/leads?select=id,data')
opens = [r['id'] for r in leads if not (r['data'].get('flags') or {}).get('approached') and r['data'].get('phase')!='dead']
print(f"open leads gevonden: {len(opens)} van {len(leads)} totaal")
moved=0
for i in range(0,len(opens),50):
    chunk=opens[i:i+50]
    ids=','.join('"'+c+'"' if ',' in c else c for c in chunk)
    s, r = req(f"/rest/v1/leads?id=in.({ids})", 'PATCH', {'setter_id':uid})
    if s not in (200,204): print('FOUT patch:', s, str(r)[:150]); raise SystemExit(1)
    moved += len(chunk)
print(f"verplaatst naar Eliza: {moved} leads — rest blijft bij Rutger")
PY
