"""Calls the deployed breed-image function as a fresh anonymous user (nyamo × mori by default).

    python3 supabase/tests/live_breed_check.py [parentA parentB]

Prints the account id so it can be deleted afterwards (delete from auth.users where id = '...').
"""
import base64, io, json, sys, urllib.request, urllib.error
from pathlib import Path
from PIL import Image

URL = "https://ofwexbasbwumfvswkixb.supabase.co"
KEY = "sb_publishable_Jmnq2XZohnNY0VnR0X8geQ_LAYusEtr"
ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "ios/SCOO/Resources/Assets.xcassets"

def png(key):
    folder = next(ASSETS.glob(f"*-{key}.imageset"))
    image = Image.open(next(folder.glob("*.png"))).convert("RGBA").resize((512, 512))
    out = io.BytesIO(); image.save(out, "PNG")
    return base64.b64encode(out.getvalue()).decode()

def call(path, body, token=None, timeout=150):
    headers = {"apikey": KEY, "Content-Type": "application/json"}
    if token: headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(URL + path, data=json.dumps(body).encode(), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        return error.code, error.read().decode(errors="replace")[:300]

a, b = (sys.argv[1], sys.argv[2]) if len(sys.argv) > 2 else ("nyamo", "mori")
status, session = call("/auth/v1/signup", {"data": {}})
print("signup", status)
token = session["access_token"]
print("signed out call", call("/functions/v1/breed-image", {"parentA": a, "parentB": b}))
print("same parents", call("/functions/v1/breed-image", {"parentA": a, "parentB": a}, token))
print("draw", call("/functions/v1/breed-image", {"parentA": a, "parentB": b, "imageA": png(a), "imageB": png(b)}, token))
print("account", session["user"]["id"])
