import httpx

from backend.response_filters import limpiar_respuesta_modelo


def consultar_sin_thinking(prompt: str) -> str:
    response = httpx.post(
        "http://localhost:11434/api/generate",
        json={
            "model": "pygenesis-resolve",
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.2,
                "top_p": 0.95,
                "top_k": 20,
                "presence_penalty": 1.5,
            },
        },
        timeout=120,
    )
    data = response.json()
    return limpiar_respuesta_modelo(data.get("response", ""))


if __name__ == "__main__":
    respuesta = consultar_sin_thinking(
        "¿Cómo configuro proxies en DaVinci Resolve para editar material 4K?"
    )
    print("\n--- RESPUESTA FINAL ---")
    print(respuesta)
