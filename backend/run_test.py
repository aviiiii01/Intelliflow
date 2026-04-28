import requests
import json
import base64

pdf_url = "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf"
res = requests.get(pdf_url)
with open("real.pdf", "wb") as f:
    f.write(res.content)

upload_res = requests.post("http://127.0.0.1:8000/uploadfile/", files={"file": ("real.pdf", open("real.pdf", "rb"))})
print("Upload status:", upload_res.status_code, upload_res.text)

payload = {
  "name": "Test Stack KB Real",
  "description": "desc",
  "workflow_definition": {
    "nodes": [
      {
        "id": "1",
        "data": {"label": "User Query"}
      },
      {
        "id": "2",
        "data": {"label": "Knowledge Base", "fileName": "real.pdf"}
      },
      {
        "id": "3",
        "data": {"label": "Gemini AI", "prompt": "Answer using context", "model": "gemini-2.5-flash"}
      }
    ],
    "edges": [
      {"source": "1", "target": "2"},
      {"source": "2", "target": "3"}
    ]
  }
}

create_res = requests.post("http://127.0.0.1:8000/stacks/", json=payload)
stack_id = create_res.json()["id"]

run_res = requests.post(f"http://127.0.0.1:8000/stacks/{stack_id}/run", json={"query": "What is this document about?"})
print("Run Stack:", run_res.status_code)
print(json.dumps(run_res.json(), indent=2))
