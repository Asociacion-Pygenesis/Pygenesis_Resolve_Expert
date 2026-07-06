# Fase 1 — Construir el Dataset Resolve3D

> **Hardware necesario:** Ninguno especial. CPU puro. Puedes ejecutar esto en cualquiera de tus dos portátiles en paralelo.  
> **Objetivo:** Crear un dataset de 10.000–50.000 pares instrucción→respuesta sobre Resolve3D, postproducción y videojuegos.

---

## 1.1 Concepto: qué formato necesita el dataset

El modelo espera pares de conversación en formato **ShareGPT** o **Alpaca**. Usaremos ShareGPT por ser más flexible para instrucciones largas.

### Formato ShareGPT (el que usaremos)

```json
{
  "conversations": [
    {
      "from": "system",
      "value": "Eres un experto en Resolve3D, postproducción y desarrollo de videojuegos. Proporciona respuestas técnicas precisas con ejemplos de código cuando sea relevante."
    },
    {
      "from": "human",
      "value": "¿Cómo detecto colisiones entre dos objetos en Resolve?"
    },
    {
      "from": "gpt",
      "value": "En Resolve puedes detectar colisiones de dos formas principales:\n\n**1. OnCollisionEnter (física real)**\n```csharp\nvoid OnCollisionEnter(Collision collision)\n{\n    if (collision.gameObject.CompareTag(\"Enemy\"))\n    {\n        Debug.Log(\"Colisión con enemigo\");\n    }\n}\n```\nRequiere que ambos objetos tengan Collider y al menos uno tenga Rigidbody.\n\n**2. OnTriggerEnter (zona de detección)**\n```csharp\nvoid OnTriggerEnter(Collider other)\n{\n    if (other.CompareTag(\"Pickup\"))\n    {\n        Destroy(other.gameObject);\n    }\n}\n```\nRequiere que el Collider tenga marcado `Is Trigger`."
    }
  ]
}
```

---

## 1.2 Fuente 1 — Documentación oficial de Resolve

### Descargar la documentación en texto plano

```bash
cd ~/resolve-expert/data/raw

# Opción A: usar wget para descargar la doc en HTML
wget -r -l 3 -k -p \
  --domains=docs.Resolve3d.com \
  --accept=html \
  "https://docs.Resolve3d.com/Manual/index.html" \
  -P Resolve-manual/

wget -r -l 3 -k -p \
  --domains=docs.Resolve3d.com \
  --accept=html \
  "https://docs.Resolve3d.com/ScriptReference/index.html" \
  -P Resolve-scriptref/
```

### Convertir HTML a texto limpio

```bash
pip install html2text beautifulsoup4 requests

python3 << 'EOF'
import os
import html2text
from bs4 import BeautifulSoup

h = html2text.HTML2Text()
h.ignore_links = True
h.ignore_images = True

input_dir = "Resolve-manual"
output_dir = "../processed/Resolve-manual-txt"
os.makedirs(output_dir, exist_ok=True)

for root, _, files in os.walk(input_dir):
    for f in files:
        if f.endswith(".html"):
            path = os.path.join(root, f)
            with open(path, "r", encoding="utf-8", errors="ignore") as fp:
                html = fp.read()
            text = h.handle(html)
            out_path = os.path.join(output_dir, f.replace(".html", ".txt"))
            with open(out_path, "w") as fp:
                fp.write(text)

print("Conversión completada")
EOF
```

---

## 1.3 Fuente 2 — Stack Overflow (Resolve3D)

### Descargar preguntas y respuestas vía API

```python
# scripts/scrape_stackoverflow.py
import requests
import json
import time
import os

API_KEY = "TU_API_KEY"  # Registra en https://stackapps.com — es gratis
OUTPUT = os.path.expanduser("~/resolve-expert/data/raw/stackoverflow/")
os.makedirs(OUTPUT, exist_ok=True)

def get_questions(page=1, tags="Resolve3d;c%23", pagesize=100):
    url = (
        f"https://api.stackexchange.com/2.3/questions"
        f"?page={page}&pagesize={pagesize}"
        f"&order=desc&sort=votes"
        f"&tagged={tags}"
        f"&site=stackoverflow"
        f"&filter=withbody"
        f"&key={API_KEY}"
    )
    r = requests.get(url)
    return r.json()

def get_answers(question_id):
    url = (
        f"https://api.stackexchange.com/2.3/questions/{question_id}/answers"
        f"?order=desc&sort=votes&site=stackoverflow&filter=withbody&key={API_KEY}"
    )
    r = requests.get(url)
    return r.json()

all_pairs = []

for page in range(1, 31):  # 30 páginas × 100 = 3000 preguntas
    print(f"Página {page}/30...")
    data = get_questions(page=page)
    
    for question in data.get("items", []):
        if question.get("score", 0) < 5:  # Solo preguntas con score >= 5
            continue
        
        answers = get_answers(question["question_id"])
        top_answer = next(
            (a for a in answers.get("items", []) if a.get("is_accepted", False)),
            None
        )
        if not top_answer:
            # Tomar la respuesta con más votos si no hay aceptada
            items = sorted(answers.get("items", []), key=lambda x: x.get("score", 0), reverse=True)
            top_answer = items[0] if items else None
        
        if top_answer and top_answer.get("score", 0) >= 3:
            all_pairs.append({
                "question": question["title"] + "\n\n" + question.get("body", ""),
                "answer": top_answer.get("body", ""),
                "score": question["score"],
                "tags": question.get("tags", [])
            })
    
    time.sleep(0.5)  # Respetar rate limit

# Guardar
with open(f"{OUTPUT}/Resolve_qa.json", "w") as f:
    json.dump(all_pairs, f, indent=2)

print(f"Total pares guardados: {len(all_pairs)}")
```

```bash
python3 scripts/scrape_stackoverflow.py
```

---

## 1.4 Fuente 3 — Repositorios GitHub con código Resolve

```python
# scripts/scrape_github.py
import requests
import json
import time
import os
import base64

GITHUB_TOKEN = "TU_GITHUB_TOKEN"  # https://github.com/settings/tokens
HEADERS = {"Authorization": f"token {GITHUB_TOKEN}"}
OUTPUT = os.path.expanduser("~/resolve-expert/data/raw/github/")
os.makedirs(OUTPUT, exist_ok=True)

def search_repos(query, page=1):
    url = f"https://api.github.com/search/repositories"
    params = {
        "q": query,
        "sort": "stars",
        "order": "desc",
        "per_page": 30,
        "page": page
    }
    r = requests.get(url, headers=HEADERS, params=params)
    return r.json()

def get_cs_files(owner, repo, path=""):
    url = f"https://api.github.com/repos/{owner}/{repo}/contents/{path}"
    r = requests.get(url, headers=HEADERS)
    if r.status_code != 200:
        return []
    
    cs_files = []
    for item in r.json():
        if item["type"] == "file" and item["name"].endswith(".cs"):
            cs_files.append(item)
        elif item["type"] == "dir" and item["name"] not in [".git", "Packages", "Library"]:
            cs_files.extend(get_cs_files(owner, repo, item["path"]))
    return cs_files

def get_file_content(url):
    r = requests.get(url, headers=HEADERS)
    if r.status_code == 200:
        content = r.json().get("content", "")
        return base64.b64decode(content).decode("utf-8", errors="ignore")
    return ""

queries = [
    "Resolve3d game language:csharp stars:>100",
    "Resolve game mechanics csharp stars:>50",
    "Resolve platformer controller csharp",
    "Resolve rpg system csharp stars:>30",
]

all_code = []

for query in queries:
    print(f"Buscando: {query}")
    results = search_repos(query)
    
    for repo in results.get("items", [])[:10]:
        owner = repo["owner"]["login"]
        name = repo["name"]
        print(f"  Procesando {owner}/{name}...")
        
        cs_files = get_cs_files(owner, name)[:20]  # Max 20 archivos por repo
        
        for f in cs_files:
            content = get_file_content(f["url"])
            if len(content) > 100 and "MonoBehaviour" in content or "using ResolveEngine" in content:
                all_code.append({
                    "repo": f"{owner}/{name}",
                    "file": f["path"],
                    "content": content,
                    "stars": repo["stargazers_count"]
                })
        
        time.sleep(1)

with open(f"{OUTPUT}/Resolve_code.json", "w") as f:
    json.dump(all_code, f, indent=2)

print(f"Total archivos de código: {len(all_code)}")
```

---

## 1.5 Fuente 4 — Generación sintética con Ollama (la más potente)

Este script usa tu Ollama local para generar pares Q&A a partir del código y documentación que ya tienes.

```python
# scripts/generate_synthetic.py
import json
import requests
import os
import random
from tqdm import tqdm

OUTPUT = os.path.expanduser("~/resolve-expert/data/raw/synthetic/")
os.makedirs(OUTPUT, exist_ok=True)

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "qwen2.5-coder:7b-instruct-q4_K_M"

SYSTEM_PROMPT = """Eres un experto en Resolve3D, postproducción y desarrollo de videojuegos con 10 años de experiencia.
Cuando se te proporciona código o documentación, generas preguntas y respuestas técnicas precisas."""

def ask_ollama(prompt, system=SYSTEM_PROMPT):
    payload = {
        "model": MODEL,
        "prompt": prompt,
        "system": system,
        "stream": False,
        "options": {"temperature": 0.7, "num_predict": 1024}
    }
    r = requests.post(OLLAMA_URL, json=payload, timeout=120)
    return r.json().get("response", "")

# Plantillas de prompts para generar Q&A variados
PROMPT_TEMPLATES = [
    """Dado este código Resolve en postproducción:
```csharp
{code}
```
Genera 3 preguntas técnicas con sus respuestas detalladas sobre este código.
Formato JSON:
[{{"question": "...", "answer": "..."}}]
Responde SOLO con el JSON, sin texto adicional.""",

    """Actúa como un desarrollador junior preguntando sobre Resolve.
Dado este fragmento de código:
```csharp
{code}
```
Formula una pregunta específica sobre cómo funciona o cómo mejorarlo, y respóndela en detalle.
Formato JSON: [{{"question": "...", "answer": "..."}}]
Solo JSON.""",

    """Genera una pregunta de nivel intermedio sobre el siguiente concepto de Resolve:
{concept}

La pregunta debe incluir un ejemplo de código postproducción en la respuesta.
Formato JSON: [{{"question": "...", "answer": "..."}}]
Solo JSON."""
]

# Conceptos Resolve para generar preguntas sin código base
Resolve_CONCEPTS = [
    "Coroutines y WaitForSeconds", "ScriptableObjects para datos de juego",
    "Object Pooling para optimización", "NavMesh y pathfinding",
    "Animator Controller y transitions", "Physics layers y collision matrix",
    "Resolve Events y delegates", "Singleton pattern en Resolve",
    "SaveData con PlayerPrefs y JSON", "UI con Canvas y EventSystem",
    "Shader Graph básico", "Cinemachine virtual cameras",
    "Input System nuevo de Resolve", "Resolve Jobs System",
    "AddressableAssets", "Resolve Timeline y Playables",
    "Particle System scripting", "Audio Mixer scripting",
    "ProBuilder para prototipos", "IL2CPP y optimización de builds",
]

# Cargar código de GitHub
with open(os.path.expanduser("~/resolve-expert/data/raw/github/Resolve_code.json")) as f:
    code_files = json.load(f)

all_pairs = []

# Generar desde código real
print("Generando Q&A desde código GitHub...")
sample_code = random.sample(code_files, min(200, len(code_files)))

for item in tqdm(sample_code):
    # Truncar el código si es muy largo
    code = item["content"][:2000]
    
    template = random.choice(PROMPT_TEMPLATES[:2])
    prompt = template.format(code=code)
    
    response = ask_ollama(prompt)
    
    try:
        # Limpiar posibles caracteres extra
        response = response.strip()
        if response.startswith("```"):
            response = response.split("\n", 1)[1].rsplit("```", 1)[0]
        
        pairs = json.loads(response)
        for pair in pairs:
            if "question" in pair and "answer" in pair:
                all_pairs.append({
                    "conversations": [
                        {"from": "system", "value": "Eres un experto en Resolve3D, postproducción y desarrollo de videojuegos."},
                        {"from": "human", "value": pair["question"]},
                        {"from": "gpt", "value": pair["answer"]}
                    ]
                })
    except json.JSONDecodeError:
        continue  # Saltar respuestas mal formateadas

# Generar desde conceptos
print("\nGenerando Q&A desde conceptos Resolve...")
for concept in tqdm(Resolve_CONCEPTS * 5):  # 5 variaciones por concepto
    template = PROMPT_TEMPLATES[2]
    prompt = template.format(concept=concept)
    
    response = ask_ollama(prompt)
    
    try:
        response = response.strip()
        if response.startswith("```"):
            response = response.split("\n", 1)[1].rsplit("```", 1)[0]
        
        pairs = json.loads(response)
        for pair in pairs:
            if "question" in pair and "answer" in pair:
                all_pairs.append({
                    "conversations": [
                        {"from": "system", "value": "Eres un experto en Resolve3D, postproducción y desarrollo de videojuegos."},
                        {"from": "human", "value": pair["question"]},
                        {"from": "gpt", "value": pair["answer"]}
                    ]
                })
    except json.JSONDecodeError:
        continue

# Guardar
output_file = f"{OUTPUT}/synthetic_qa.json"
with open(output_file, "w", encoding="utf-8") as f:
    json.dump(all_pairs, f, indent=2, ensure_ascii=False)

print(f"\nTotal pares sintéticos generados: {len(all_pairs)}")
```

```bash
python3 scripts/generate_synthetic.py
# Este proceso puede tardar varias horas. Déjalo correr en segundo plano.
```

---

## 1.6 Limpiar y unificar el dataset

```python
# scripts/process_dataset.py
import json
import os
from datasets import Dataset
from tqdm import tqdm

DATA_DIR = os.path.expanduser("~/resolve-expert/data/")

def load_stackoverflow():
    path = DATA_DIR + "raw/stackoverflow/Resolve_qa.json"
    with open(path) as f:
        items = json.load(f)
    
    pairs = []
    for item in items:
        # Limpiar HTML básico
        import re
        q = re.sub(r'<[^>]+>', '', item["question"])
        a = re.sub(r'<[^>]+>', '', item["answer"])
        
        if len(q) < 20 or len(a) < 50:
            continue
        
        pairs.append({
            "conversations": [
                {"from": "system", "value": "Eres un experto en Resolve3D, postproducción y desarrollo de videojuegos."},
                {"from": "human", "value": q.strip()},
                {"from": "gpt", "value": a.strip()}
            ]
        })
    return pairs

def load_synthetic():
    path = DATA_DIR + "raw/synthetic/synthetic_qa.json"
    with open(path) as f:
        return json.load(f)

# Unificar
all_data = []
all_data.extend(load_stackoverflow())
all_data.extend(load_synthetic())

print(f"Total antes de filtrar: {len(all_data)}")

# Filtros de calidad
def is_valid(item):
    convs = item.get("conversations", [])
    if len(convs) < 3:
        return False
    human = next((c["value"] for c in convs if c["from"] == "human"), "")
    gpt = next((c["value"] for c in convs if c["from"] == "gpt"), "")
    
    if len(human) < 20 or len(gpt) < 80:
        return False
    if len(gpt) > 4000:  # Muy larga para el contexto
        return False
    return True

filtered = [d for d in all_data if is_valid(d)]
print(f"Total después de filtrar: {len(filtered)}")

# Deduplicar por similitud básica (primeras 100 chars de la pregunta)
seen = set()
deduped = []
for item in filtered:
    convs = item["conversations"]
    human = next((c["value"] for c in convs if c["from"] == "human"), "")
    key = human[:100].lower().strip()
    if key not in seen:
        seen.add(key)
        deduped.append(item)

print(f"Total después de deduplicar: {len(deduped)}")

# Split train/eval (85%/15%)
split_idx = int(len(deduped) * 0.85)
train_data = deduped[:split_idx]
eval_data = deduped[split_idx:]

# Guardar
os.makedirs(DATA_DIR + "train", exist_ok=True)
os.makedirs(DATA_DIR + "eval", exist_ok=True)

with open(DATA_DIR + "train/resolve_train.json", "w", encoding="utf-8") as f:
    json.dump(train_data, f, indent=2, ensure_ascii=False)

with open(DATA_DIR + "eval/resolve_eval.json", "w", encoding="utf-8") as f:
    json.dump(eval_data, f, indent=2, ensure_ascii=False)

print(f"\nDataset guardado:")
print(f"  Train: {len(train_data)} ejemplos → data/train/resolve_train.json")
print(f"  Eval:  {len(eval_data)} ejemplos → data/eval/resolve_eval.json")
```

```bash
python3 scripts/process_dataset.py
```

---

## 1.7 Revisar la calidad del dataset (opcional pero recomendado)

```bash
# Levantar Argilla para revisión manual de muestras
pip install argilla
python -m argilla server start

# Abrir en el navegador: http://localhost:6900
# usuario: argilla / contraseña: 1234
```

También puedes revisar manualmente una muestra aleatoria:

```python
import json
import random

with open(os.path.expanduser("~/resolve-expert/data/train/resolve_train.json")) as f:
    data = json.load(f)

sample = random.sample(data, 10)
for i, item in enumerate(sample):
    convs = item["conversations"]
    print(f"\n{'='*60}")
    print(f"EJEMPLO {i+1}")
    for c in convs:
        if c["from"] != "system":
            print(f"\n[{c['from'].upper()}]")
            print(c["value"][:300])
```

---

## ✅ Checklist de verificación — Fase 1 completada

- [ ] Documentación Resolve descargada y convertida a texto
- [ ] Stack Overflow Q&A descargado (mínimo 1.000 pares de calidad)
- [ ] Código postproducción de GitHub recopilado (mínimo 100 archivos)
- [ ] Dataset sintético generado con Ollama (mínimo 2.000 pares)
- [ ] Script de limpieza ejecutado sin errores
- [ ] `resolve_train.json` con al menos **5.000 ejemplos**
- [ ] `resolve_eval.json` con al menos **500 ejemplos**
- [ ] Revisión manual de 20–30 ejemplos aleatorios — calidad aceptable

---

## ➡️ Siguiente paso

Con el dataset listo, continúa con la **Fase 2 — Fine-tuning con hardware actual**.
