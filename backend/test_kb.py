import requests
import json
import sqlite3

# Create a small valid PDF using markdown/reportlab or simply a minimal PDF content
pdf_content = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n4 0 obj\n<< /Length 53 >>\nstream\nBT\n/F1 24 Tf\n100 700 Td\n(Hello World from PDF) Tj\nET\nendstream\nendobj\n5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\nxref\n0 6\n0000000000 65535 f \n0000000009 00000 n \n0000000058 00000 n \n0000000115 00000 n \n0000000225 00000 n \n0000000329 00000 n \ntrailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n417\n%%EOF\n"

with open("test.pdf", "wb") as f:
    f.write(pdf_content)

res = requests.post("http://127.0.0.1:8000/uploadfile/", files={"file": ("test.pdf", open("test.pdf", "rb"))})
print("Upload status:", res.status_code, res.text)

payload = {
  "name": "Test Stack",
  "description": "desc",
  "workflow_definition": {
    "nodes": [
      {
        "id": "1",
        "data": {"label": "User Query"}
      },
      {
        "id": "2",
        "data": {"label": "Knowledge Base", "fileName": "test.pdf"}
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

res2 = requests.post("http://127.0.0.1:8000/stacks/", json=payload)
print("Create Stack:", res2.status_code, res2.json())
stack_id = res2.json()["id"]

res3 = requests.post(f"http://127.0.0.1:8000/stacks/{stack_id}/run", json={"query": "What does the PDF say?"})
print("Run Stack:", res3.status_code)
print(json.dumps(res3.json(), indent=2))
