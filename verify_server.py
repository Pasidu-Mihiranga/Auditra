
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

base_url = "http://127.0.0.1:8000"
headers = {'Content-Type': 'application/json'}

def test(url, method="POST", data=None):
    full_url = base_url + url
    print(f"TESTING: {method} {full_url}")
    try:
        if method == "POST":
            resp = requests.post(full_url, headers=headers, json=data, timeout=10)
        else:
            resp = requests.get(full_url, headers=headers, timeout=10)
        
        print(f"STATUS: {resp.status_code}")
        print(f"RESPONSE: {resp.text[:500]}")
    except Exception as e:
        print(f"EXCEPTION: {e}")
    print("-" * 20)

# 1. Login
test("/api/auth/login/", data={"username": "test", "password": "password123"})

# 2. Register attempt
test("/api/auth/register/", data={"username": "newuser", "email": "test@test.com", "password": "Test123!", "password2": "Test123!"})
