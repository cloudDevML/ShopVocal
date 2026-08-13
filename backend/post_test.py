import urllib.request, json
import urllib.error

payload = {"text": "J'ai vendu 3 bouteilles d'huile à 2000 FCFA à la cliente Aminata"}
data = json.dumps(payload).encode('utf-8')
req = urllib.request.Request('http://127.0.0.1:8000/ai/text-to-action', data=data, headers={'Content-Type':'application/json'})
try:
    with urllib.request.urlopen(req, timeout=10) as resp:
        print('STATUS', resp.status)
        body = resp.read().decode('utf-8')
        print(body)
except urllib.error.HTTPError as e:
    print('HTTP ERROR', e.code)
    try:
        print(e.read().decode('utf-8'))
    except Exception:
        pass
except Exception as e:
    print('ERROR', repr(e))
