# Pygenesis ResolveExpert

Asistente de IA **local** para **DaVinci Resolve** (Edit, Color, Fusion, Fairlight, Deliver).

| Edición | Cómo se usa |
|---------|-------------|
| **Resolve Studio** | Plugin integrado: `Workspace → Workflow Integrations → Pygenesis Resolve Tutor` |
| **Resolve Free** | [Pygenesis Companion](companion/README.md) (ventana de chat flotante) |

El modelo es el mismo en ambos casos. En Studio el contexto (página/proyecto/timeline) puede enviarse automáticamente; en Free se indica a mano en Companion.

**English:** [README.md](README.md)

---

## Inicio rápido (usuarios)

**Requisitos:** Windows 10/11, [Python 3.10+](https://www.python.org/downloads/) en PATH, Internet (primera descarga del modelo).

1. Descarga **Pygenesis Companion** desde [GitHub Releases](https://github.com/Asociacion-Pygenesis/Pygenesis_Resolve_Expert/releases).
2. Ejecuta el `.exe` portable.
3. Pulsa **Instalar lo que falta** (runtime, GGUF desde Hugging Face, plugin Studio).
4. **Arrancar puente** → **Continuar al chat**.

Los pesos GGUF **no** están en este repositorio. Se descargan desde Hugging Face:

[`SuNavar/Pygenesis_ResolveExpert`](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert)

Alternativa sin interfaz: clona el repo y ejecuta [`Install.bat`](Install.bat).

---

## Estructura del repositorio

| Ruta | Rol |
|------|-----|
| [`installer/`](installer/) | Instalador cerrado (`Install.bat`), fuente HF, scripts de release |
| [`backend/`](backend/) | Puente FastAPI local + `llama-cpp-python` (GGUF) |
| [`plugin/`](plugin/) | Plugin Workflow Integration (Resolve Studio) |
| [`companion/`](companion/) | Companion Electron + asistente de instalación |
| [`training/`](training/) | Dataset / fine-tuning (solo desarrollo) |
| [`conversion/`](conversion/) | LoRA → GGUF (solo desarrollo) |

---

## Desarrolladores

```powershell
# Opcional: venv de entrenamiento
Set-Location training
.\scripts\setup_env_windows.ps1

# Instalar runtime + modelo + plugin desde fuentes
.\Install.bat

# Companion en modo desarrollo
Set-Location companion\pygenesis-companion
npm install
npm start

# Generar .exe portable
npm run build
```

Empaquetado: [`installer/build_release.ps1`](installer/build_release.ps1) · publicación: [`installer/publish_release.ps1`](installer/publish_release.ps1)

---

## Privacidad y licencia

La inferencia corre **en tu máquina**. No hace falta API de chat en la nube más allá de descargar el modelo una vez.

Licencia [Apache-2.0](LICENSE).

---

## Enlaces

- Modelo: [Hugging Face — SuNavar/Pygenesis_ResolveExpert](https://huggingface.co/SuNavar/Pygenesis_ResolveExpert)
- Releases: [GitHub Releases](https://github.com/Asociacion-Pygenesis/Pygenesis_Resolve_Expert/releases)
- Asociación: [Asociacion-Pygenesis](https://github.com/Asociacion-Pygenesis)
