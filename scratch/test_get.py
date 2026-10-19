import urllib.request
try:
    response = urllib.request.urlopen("http://127.0.0.1:8000/leaderboard")
    data = response.read()
    print("Response status code:", response.status)
    print("Response headers:\n", response.headers)
    print("Response body:")
    print(data)
    print("Decoded body:")
    print(data.decode('utf-8'))
except Exception as e:
    print("Error:", e)
