"""Two fresh anonymous accounts become friends by code and exchange letters on the live project.
Prints both account ids so they can be deleted afterwards."""
import json, urllib.request, urllib.error

URL = "https://ofwexbasbwumfvswkixb.supabase.co"
KEY = "sb_publishable_Jmnq2XZohnNY0VnR0X8geQ_LAYusEtr"

def call(path, body=None, token=None, method=None):
    headers = {"apikey": KEY, "Content-Type": "application/json"}
    if token: headers["Authorization"] = "Bearer " + token
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(URL + path, data=data, headers=headers, method=method or ("POST" if data else "GET"))
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode(errors="replace")[:200]

a = call("/auth/v1/signup", {"data": {}})[1]; b = call("/auth/v1/signup", {"data": {}})[1]
A, B = a["access_token"], b["access_token"]
code_a = call("/rest/v1/rpc/my_profile", {}, A)[1][0]["friend_code"]
print("A profile", call("/rest/v1/rpc/my_profile", {}, A))
print("A nickname", call(f"/rest/v1/profiles?id=eq.{a['user']['id']}", {"nickname": "에이", "hero": "nyamo"}, A, "PATCH"))
print("B asks A", call("/rest/v1/rpc/request_friend", {"p_code": code_a.lower()}, B))
print("B early letter", call("/rest/v1/rpc/send_message", {"p_to": a["user"]["id"], "p_body": "안녕", "p_sticker": None}, B))
print("A list", call("/rest/v1/rpc/list_friends", {}, A))
print("A accepts", call("/rest/v1/rpc/respond_friend", {"p_requester": b["user"]["id"], "p_accept": True}, A))
print("B letter", call("/rest/v1/rpc/send_message", {"p_to": a["user"]["id"], "p_body": "안녕! 오늘 바다 봤어", "p_sticker": None}, B))
print("B sticker", call("/rest/v1/rpc/send_message", {"p_to": a["user"]["id"], "p_body": None, "p_sticker": "tori"}, B))
print("A list", call("/rest/v1/rpc/list_friends", {}, A))
print("A chat", call(f"/rest/v1/my_messages?friend_id=eq.{b['user']['id']}&order=created_at.asc&limit=300", token=A))
print("A read", call("/rest/v1/rpc/mark_read", {"p_friend": b["user"]["id"]}, A))
print("B sees A as", call("/rest/v1/rpc/list_friends", {}, B))
print("ids", a["user"]["id"], b["user"]["id"])
