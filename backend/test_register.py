import requests

url = "http://127.0.0.1:8000/api/v1/persons/4/register-face"

# Apni photos ke paths yahan daalo
photo_paths = [
    r"C:\Users\mohit\internet DOwnload\chico1.jpg",
    r"C:\Users\mohit\internet DOwnload\chico2.jpg",
    r"C:\Users\mohit\internet DOwnload\chico3.jpg",
]

files = []
for path in photo_paths:
    f = open(path, "rb")
    files.append(("files", f))

print("Uploading...")
response = requests.post(url, files=files)

print(f"Status: {response.status_code}")
print(f"Response: {response.json()}")

# Close files
for _, f in files:
    f.close()