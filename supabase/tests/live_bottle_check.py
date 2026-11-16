import json, time, urllib.request, urllib.error
URL = "https://ofwexbasbwumfvswkixb.supabase.co"
KEY = "sb_publishable_Jmnq2XZohnNY0VnR0X8geQ_LAYusEtr"

def req(path, body=None, token=None, method=None):
    headers = {"apikey": KEY, "Content-Type": "application/json", "Accept": "application/json"}
    if token: headers["Authorization"] = "Bearer " + token
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(URL + path, data=data, headers=headers, method=method or ("POST" if data else "GET"))
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return resp.status, json.loads(resp.read() or b"null")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace")[:300]

def signup():
    code, out = req("/auth/v1/signup", {"data": {}})
    print("signup", code, out if code != 200 else ("user", out["user"]["id"][:8], "anon", out["user"].get("is_anonymous")))
    return out if code == 200 else None

a = signup(); b = signup()
if a and b:
    A, B = a["access_token"], b["access_token"]
    print("A send", req("/rest/v1/rpc/send_bottle", {"p_parent_a": "tori", "p_parent_b": "sia", "p_origin": "마포구", "p_wants_news": True, "p_fast": True}, A))
    print("A sees", req("/rest/v1/my_bottles?select=direction,parent_a,arrives_at", token=A))
    print("B send", req("/rest/v1/rpc/send_bottle", {"p_parent_a": "nyamo", "p_parent_b": "dia", "p_origin": "성동구", "p_wants_news": False, "p_fast": True}, B))
    code, rows = req("/rest/v1/my_bottles?select=id,direction,parent_a,origin,arrives_at,opened", token=B)
    print("B sees", code, rows)
    print("B direct insert", req("/rest/v1/bottles", {"sender": b["user"]["id"], "parent_a": "x", "parent_b": "y", "origin": "z"}, B))
    print("anon rpc", req("/rest/v1/rpc/send_bottle", {"p_parent_a": "x", "p_parent_b": "y", "p_origin": "z", "p_wants_news": False}))
    incoming = [r for r in rows if r["direction"] == "incoming"] if code == 200 else []
    if incoming:
        print("B open early", req("/rest/v1/rpc/open_bottle", {"p_id": incoming[0]["id"]}, B))
        time.sleep(62)
        print("B open after a minute", req("/rest/v1/rpc/open_bottle", {"p_id": incoming[0]["id"]}, B))
        print("B open twice", req("/rest/v1/rpc/open_bottle", {"p_id": incoming[0]["id"]}, B))
    print("ids", a["user"]["id"], b["user"]["id"])
