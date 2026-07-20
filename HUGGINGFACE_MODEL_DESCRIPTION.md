---
language:
- en
license: apache-2.0
pipeline_tag: text-generation
library_name: llama-cpp
tags:
- davinci-resolve
- video-editing
- local-inference
- gguf
- qwen
base_model: Qwen/Qwen2.5-7B-Instruct
---

# Pygenesis ResolveExpert

Pygenesis ResolveExpert is a task-oriented assistant model for **DaVinci Resolve** workflows (Edit, Color, Fusion, Fairlight, Deliver), packaged for local inference as GGUF.

## Model Overview

`pygenesis-resolve-q4km.gguf` is a quantized local-inference variant of a Resolve-focused fine-tuned model.

Main goals:
- Provide practical, step-by-step help for real editing and post-production tasks.
- Keep latency reasonable on desktop hardware.
- Run fully on-device with no cloud dependency.

## Studio vs Free: Context Behavior

The model is the same in both editions.  
The key difference is **how runtime context is provided**.

### DaVinci Resolve Studio (Integrated Plugin)

In Studio, the Workflow Integration plugin can automatically read and pass context such as:
- Current Resolve page (`Media`, `Cut`, `Edit`, `Fusion`, `Color`, `Fairlight`, `Deliver`)
- Current project and timeline names
- Basic timeline metadata

This usually improves relevance because answers are grounded in the user’s current working state.

### DaVinci Resolve Free (Companion App)

Resolve Free does not support the Workflow Integration plugin, so usage is via **Pygenesis Companion** (external app).

In this mode, context is provided manually:
- User selects the active page
- User can optionally provide project/timeline names

The model quality is unchanged, but contextual precision depends on the information entered by the user.

## Practical Summary

- **Same model weights** in Studio and Free.
- **Studio**: automatic context -> more situational responses.
- **Free**: manual context -> still useful responses, with lower contextual precision when input context is incomplete.

## Recommended Use Cases

- Resolve workflow troubleshooting ("how do I do X in Color/Fusion/Edit?").
- Page-specific checklists ("what should I review here?").
- Export and performance best practices.
- Actionable next steps for practical post-production decisions.

## Limitations

- Not a replacement for official Blackmagic documentation.
- Advanced workflows may still require iterative clarification.
- In Free mode, missing manual context can reduce specificity.

## Prompting Tips

For best results, include:
- Current Resolve page.
- Clear goal ("match two shots", "export for YouTube 4K", etc.).
- Constraints (GPU, Resolve version, footage type, deadline).

Example:
> "I am on the Color page. I have two shots with different exposure and need a fast matching workflow without damaging skin tones."

## Installation & Usage

Pygenesis ResolveExpert is distributed as a **Windows app** (Pygenesis Companion `.exe`).

On first launch the app shows what is installed and what is missing, then can install:
- GPU/CPU inference runtime
- Model download from **this** Hugging Face repository (`pygenesis-resolve-q4km.gguf`)
- Resolve Studio plugin
- Local bridge

You can also use `Install.bat` from the GitHub package.
After installation:

| Edition | How you use it |
|---------|----------------|
| **DaVinci Resolve Studio** | Open the integrated plugin from **Workspace → Workflow Integrations → Pygenesis Resolve Tutor** |
| **DaVinci Resolve Free** | Launch **Pygenesis Companion** from the Start Menu |

Inference runs locally on your machine. No account or API key is required beyond downloading the model through the installer.

Application / installer source: GitHub distribution package for Pygenesis ResolveExpert (GGUF weights stay on Hugging Face).

## Intended Users

Editors, colorists, and technical users who want a local assistant tailored to DaVinci Resolve workflows.

## Acknowledgements

- Built for the Pygenesis ResolveExpert project.
- Resolve integration behavior follows Blackmagic’s Studio/Free plugin constraints.
