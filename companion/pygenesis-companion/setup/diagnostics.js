"use strict";

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const http = require("http");
const os = require("os");

const MODEL_FILENAME = "pygenesis-resolve-q4km.gguf";
const PLUGIN_ID = "com.pygenesis.davinci.tutor";

function localAppData() {
  return process.env.LOCALAPPDATA || path.join(os.homedir(), "AppData", "Local");
}

function programData() {
  return process.env.PROGRAMDATA || "C:\\ProgramData";
}

function pygenesisHome() {
  return path.join(localAppData(), "Pygenesis");
}

function readBridgeEnv() {
  const envPath = path.join(pygenesisHome(), "bridge.env");
  const out = {};
  if (!fs.existsSync(envPath)) return out;
  const text = fs.readFileSync(envPath, "utf8");
  for (const line of text.split(/\r?\n/)) {
    const m = line.match(/^\s*([^#=]+)=(.*)$/);
    if (m) out[m[1].trim()] = m[2].trim();
  }
  return out;
}

function findSystemPython() {
  // Prefer 3.12/3.11/3.10 (wheels for llama-cpp-python). 3.13+ forces source builds → MAX_PATH.
  for (const ver of ["3.12", "3.11", "3.10"]) {
    try {
      const resolved = spawnSync("py", [`-${ver}`, "-c", "import sys; print(sys.executable)"], {
        encoding: "utf8",
        windowsHide: true,
        timeout: 8000,
      });
      if (resolved.status === 0 && resolved.stdout && fs.existsSync(resolved.stdout.trim())) {
        return { ok: true, path: resolved.stdout.trim(), version: ver };
      }
    } catch (_) {
      /* try next */
    }
  }

  const cmds = ["python", "python3"];
  for (const cmd of cmds) {
    try {
      const ver = spawnSync(cmd, ["-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"], {
        encoding: "utf8",
        windowsHide: true,
        timeout: 8000,
      });
      if (ver.status !== 0 || !ver.stdout) continue;
      const parts = ver.stdout.trim().split(".");
      const major = parseInt(parts[0], 10);
      const minor = parseInt(parts[1], 10);
      if (major === 3 && minor >= 10 && minor <= 12) {
        const resolved = spawnSync(cmd, ["-c", "import sys; print(sys.executable)"], {
          encoding: "utf8",
          windowsHide: true,
          timeout: 8000,
        });
        if (resolved.status === 0 && resolved.stdout && fs.existsSync(resolved.stdout.trim())) {
          return { ok: true, path: resolved.stdout.trim(), version: ver.stdout.trim() };
        }
        return { ok: true, path: cmd, version: ver.stdout.trim() };
      }
    } catch (_) {
      /* try next */
    }
  }
  return { ok: false, path: null, version: null };
}

function checkRuntime() {
  const bridge = readBridgeEnv();
  const candidates = [];
  if (bridge.PYGENESIS_PYTHON) candidates.push(bridge.PYGENESIS_PYTHON);
  candidates.push(path.join(pygenesisHome(), "runtime", "Scripts", "python.exe"));
  for (const p of candidates) {
    if (p && fs.existsSync(p)) {
      try {
        const ver = spawnSync(p, ["-c", "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"], {
          encoding: "utf8",
          windowsHide: true,
          timeout: 8000,
        });
        if (ver.status === 0 && ver.stdout) {
          const parts = ver.stdout.trim().split(".");
          const major = parseInt(parts[0], 10);
          const minor = parseInt(parts[1], 10);
          if (major === 3 && minor >= 13) {
            return {
              ok: false,
              path: p,
              detail: `Python ${ver.stdout.trim()} sin wheels; reinstala (usará 3.12)`,
            };
          }
        }
      } catch (_) {
        /* treat as present */
      }
      return { ok: true, path: p };
    }
  }
  return { ok: false, path: null };
}

function checkModel() {
  const bridge = readBridgeEnv();
  const candidates = [];
  if (bridge.PYGENESIS_MODEL_PATH) candidates.push(bridge.PYGENESIS_MODEL_PATH);
  candidates.push(path.join(pygenesisHome(), "models", MODEL_FILENAME));
  for (const p of candidates) {
    if (p && fs.existsSync(p)) {
      const sizeMb = Math.round(fs.statSync(p).size / (1024 * 1024));
      return { ok: true, path: p, sizeMb };
    }
  }
  return { ok: false, path: null, sizeMb: 0 };
}

function checkPlugin() {
  const dir = path.join(
    programData(),
    "Blackmagic Design",
    "DaVinci Resolve",
    "Support",
    "Workflow Integration Plugins",
    PLUGIN_ID
  );
  const manifest = path.join(dir, "manifest.xml");
  return { ok: fs.existsSync(manifest), path: dir };
}

function checkBridgeHealth(port) {
  const p = port || 8000;
  return new Promise((resolve) => {
    const req = http.get({ host: "127.0.0.1", port: p, path: "/health", timeout: 2000 }, (res) => {
      let body = "";
      res.on("data", (c) => (body += c));
      res.on("end", () => {
        try {
          const data = JSON.parse(body);
          resolve({ ok: res.statusCode === 200 && data.status === "ok", detail: data });
        } catch (_) {
          resolve({ ok: false, detail: null });
        }
      });
    });
    req.on("error", () => resolve({ ok: false, detail: null }));
    req.on("timeout", () => {
      req.destroy();
      resolve({ ok: false, detail: null });
    });
  });
}

function checkInstallerBundle(packageRoot) {
  const script = path.join(packageRoot, "installer", "install_pygenesis.ps1");
  const modelSrc = path.join(packageRoot, "installer", "model.source.json");
  return {
    ok: fs.existsSync(script) && fs.existsSync(modelSrc),
    script,
    packageRoot,
  };
}

function hasFullVulkanSdk() {
  const roots = [];
  if (process.env.VULKAN_SDK) roots.push(process.env.VULKAN_SDK);
  if (fs.existsSync("C:\\VulkanSDK")) {
    try {
      const dirs = fs.readdirSync("C:\\VulkanSDK", { withFileTypes: true });
      dirs
        .filter((d) => d.isDirectory())
        .map((d) => path.join("C:\\VulkanSDK", d.name))
        .sort()
        .reverse()
        .forEach((p) => roots.push(p));
    } catch (_) {
      /* ignore */
    }
  }
  for (const root of roots) {
    if (!root) continue;
    const glslc = path.join(root, "Bin", "glslc.exe");
    const include = path.join(root, "Include", "vulkan", "vulkan.h");
    const lib = path.join(root, "Lib", "vulkan-1.lib");
    if (fs.existsSync(glslc) && fs.existsSync(include) && fs.existsSync(lib)) {
      return { ok: true, path: root };
    }
  }
  return { ok: false, path: null };
}

function checkGpuBackend() {
  const bridge = readBridgeEnv();
  const configured = (bridge.PYGENESIS_GPU_BACKEND || "").toLowerCase();
  const sdk = hasFullVulkanSdk();

  if (configured === "cuda") {
    return {
      ok: true,
      required: false,
      detail: "Backend CUDA (configurado en bridge.env)",
    };
  }
  if (configured === "cpu") {
    return {
      ok: true,
      required: false,
      detail:
        "Backend CPU. En AMD, GPU requiere Vulkan SDK + VS Build Tools (C++); VulkanRT no basta.",
    };
  }
  if (configured === "vulkan") {
    return {
      ok: sdk.ok,
      required: false,
      detail: sdk.ok
        ? "Backend Vulkan — SDK: " + sdk.path
        : "Backend Vulkan en config, pero falta Vulkan SDK completo",
    };
  }

  // Not installed yet: informational tip for AMD laptops
  if (sdk.ok) {
    return {
      ok: true,
      required: false,
      detail: "Vulkan SDK detectado (" + sdk.path + "). AMD podra usar GPU al instalar.",
    };
  }
  return {
    ok: true,
    required: false,
    detail:
      "Sin Vulkan SDK. NVIDIA→CUDA; AMD sin SDK→CPU automatico. SDK: https://vulkan.lunarg.com/sdk/home",
  };
}

/**
 * @param {string} packageRoot
 * @returns {Promise<object>}
 */
async function runDiagnostics(packageRoot) {
  const python = findSystemPython();
  const runtime = checkRuntime();
  const model = checkModel();
  const plugin = checkPlugin();
  const bridge = await checkBridgeHealth(8000);
  const bundle = checkInstallerBundle(packageRoot);
  const gpu = checkGpuBackend();

  const readyForChat = runtime.ok && model.ok;
  const needsInstall =
    !runtime.ok || !model.ok || !plugin.ok || !python.ok;

  return {
    python: {
      id: "python",
      label: "Python 3.10–3.12",
      ok: python.ok,
      required: true,
      detail: python.ok ? python.version + " — " + python.path : "Instala Python 3.12 (evita 3.13/3.14)",
    },
    runtime: {
      id: "runtime",
      label: "Runtime Pygenesis",
      ok: runtime.ok,
      required: true,
      detail: runtime.ok
        ? runtime.path
        : runtime.detail || "Falta %LOCALAPPDATA%\\Pygenesis\\runtime",
    },
    model: {
      id: "model",
      label: "Modelo GGUF",
      ok: model.ok,
      required: true,
      detail: model.ok
        ? model.path + " (" + model.sizeMb + " MB)"
        : "Se descargara desde Hugging Face al instalar",
    },
    gpu: {
      id: "gpu",
      label: "Aceleracion GPU",
      ok: gpu.ok,
      required: false,
      detail: gpu.detail,
    },
    plugin: {
      id: "plugin",
      label: "Plugin Resolve Studio",
      ok: plugin.ok,
      required: false,
      detail: plugin.ok
        ? "Instalado en Workflow Integration Plugins"
        : "Opcional si usas solo Resolve Free / Companion",
    },
    bridge: {
      id: "bridge",
      label: "Puente (localhost:8000)",
      ok: bridge.ok,
      required: true,
      detail: bridge.ok ? "Activo" : "No esta en marcha (puedes arrancarlo desde aqui)",
    },
    bundle: {
      id: "bundle",
      label: "Paquete de instalacion",
      ok: bundle.ok,
      required: true,
      detail: bundle.ok ? bundle.script : "No se encontro installer\\install_pygenesis.ps1",
    },
    readyForChat,
    needsInstall,
    packageRoot,
  };
}

module.exports = {
  runDiagnostics,
  checkBridgeHealth,
  pygenesisHome,
  readBridgeEnv,
  MODEL_FILENAME,
};
