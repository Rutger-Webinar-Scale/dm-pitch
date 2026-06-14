#!/bin/bash
# Zet een bekend wachtwoord op Eliza's bestaande setter-account (geen e-mail/melding naar haar).
# Keys runtime via supabase CLI, nooit geprint.
set -e
REF="vpytvszdaepvaaclwuao"
export URL="https://$REF.supabase.co"
KEYS_JSON=$(supabase projects api-keys --project-ref "$REF" -o json 2>/dev/null)
export SERVICE_KEY=$(echo "$KEYS_JSON" | python3 -c "import json,sys;ks=json.load(sys.stdin);print(next(k['api_key'] for k in ks if k.get('name')=='service_role'))")
# vast wachtwoord (door Rutger gekozen)
export NEWPASS="ElizaDMPitch2026"

python3 <<'PY'
import json, os, urllib.request
URL=os.environ['URL']; SK=os.environ['SERVICE_KEY']; PASS=os.environ['NEWPASS']
def req(path, method='GET', data=None):
    r=urllib.request.Request(URL+path, method=method,
        data=json.dumps(data).encode() if data is not None else None,
        headers={'apikey':SK,'Authorization':'Bearer '+SK,'Content-Type':'application/json'})
    try:
        with urllib.request.urlopen(r) as resp:
            b=resp.read(); return resp.status, json.loads(b) if b else None
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b'null')

EMAIL='edegraaf.edg@gmail.com'
s, users = req("/auth/v1/admin/users?page=1&per_page=200")
u = next((x for x in (users.get('users',[]) if isinstance(users,dict) else []) if x.get('email','').lower()==EMAIL), None)
if not u:
    print('GEEN account gevonden voor', EMAIL, '- niets gewijzigd.'); raise SystemExit(1)
uid=u['id']
# admin-update: zet wachtwoord + houd e-mail bevestigd. Stuurt GEEN mail naar de gebruiker.
s, r = req(f"/auth/v1/admin/users/{uid}", 'PUT', {'password':PASS,'email_confirm':True})
if s not in (200,201):
    print('FOUT bij wachtwoord zetten:', s, str(r)[:200]); raise SystemExit(1)
print('OK — wachtwoord gezet (geen melding verstuurd).')
print('────────────────────────────')
print('  Login URL : https://rutger-webinar-scale.github.io/dm-pitch/')
print('  E-mail    :', EMAIL)
print('  Wachtwoord:', PASS)
print('────────────────────────────')
PY
