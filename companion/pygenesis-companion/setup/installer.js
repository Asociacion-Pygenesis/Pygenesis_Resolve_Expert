"use strict";

const { spawn } = require("child_process");
const path = require("path");
const fs = require("fs");
const { pygenesisHome } = require("./diagnostics");

let installProc = null;
let backendProc = null;

function powershellExe() {
  return process.env.SystemRoot
    ? path.join(process.env.SystemRoot, "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
    : "powershell.exe";
}

function psQuote(value) {
  return "'" + String(value).replace(/'/g, "''") + "'";
}

/**
 * Run closed installer. Skips Companion copy (we are already Companion).
 * @param {string} packageRoot
 * @param {{ onLine?: (line: string) => void }} hooks
 */
function runInstall(packageRoot, hooks) {
  const script = path.join(packageRoot, "installer", "install_pygenesis.ps1");
  if (!fs.existsSync(script)) {
    return Promise.reject(new Error("No se encontro " + script));
  }
  if (installProc) {
    return Promise.reject(new Error("Ya hay una instalacion en curso"));
  }

  const args = [
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    script,
    "-SkipCompanion",
  ];

  return new Promise((resolve, reject) => {
    const child = spawn(powershellExe(), args, {
      cwd: path.dirname(script),
      windowsHide: true,
      env: process.env,
    });
    installProc = child;

    const emit = (chunk, isErr) => {
      const text = chunk.toString("utf8");
      text.split(/\r?\n/).forEach((line) => {
        if (!line.trim()) return;
        if (hooks && hooks.onLine) hooks.onLine((isErr ? "[err] " : "") + line);
      });
    };

    child.stdout.on("data", (d) => emit(d, false));
    child.stderr.on("data", (d) => emit(d, true));

    child.on("error", (err) => {
      installProc = null;
      reject(err);
    });

    child.on("close", (code) => {
      installProc = null;
      if (code === 0) resolve({ ok: true, code });
      else reject(new Error("Instalacion finalizo con codigo " + code));
    });
  });
}

/**
 * Copia backend embebido -> %LOCALAPPDATA%\Pygenesis\app\backend
 * (evita ejecutar desde Temp del portable, que no deja log fiable).
 */
function syncBackendToApp(packageRoot) {
  const src = path.join(packageRoot, "backend");
  const dst = path.join(pygenesisHome(), "app", "backend");
  if (!fs.existsSync(src)) return null;
  fs.mkdirSync(path.join(pygenesisHome(), "app"), { recursive: true });
  fs.cpSync(src, dst, { recursive: true, force: true });
  const start = path.join(dst, "scripts", "start_backend.ps1");
  return fs.existsSync(start) ? start : null;
}

function resolveBackendStart(packageRoot) {
  // 1) Sincronizar desde el .exe y usar AppDir (ruta estable)
  if (packageRoot) {
    try {
      const synced = syncBackendToApp(packageRoot);
      if (synced) return synced;
    } catch (_) {
      /* fallback abajo */
    }
  }

  const appStart = path.join(pygenesisHome(), "app", "backend", "scripts", "start_backend.ps1");
  if (fs.existsSync(appStart)) return appStart;

  const pkgStart = path.join(packageRoot || "", "backend", "scripts", "start_backend.ps1");
  if (packageRoot && fs.existsSync(pkgStart)) return pkgStart;

  const homeStart = path.join(pygenesisHome(), "Start-Backend.ps1");
  if (fs.existsSync(homeStart)) return homeStart;

  return null;
}

/**
 * Start bridge fully detached; logging lo hace start_backend.ps1
 */
function startBackend(packageRoot, hooks) {
  const script = resolveBackendStart(packageRoot);
  if (!script) {
    return Promise.reject(new Error("No se encontro start_backend.ps1. Instala primero."));
  }
  if (backendProc && !backendProc.killed) {
    return Promise.resolve({ ok: true, already: true, script });
  }

  const logDir = path.join(pygenesisHome(), "logs");
  fs.mkdirSync(logDir, { recursive: true });
  const logPath = path.join(logDir, "backend.log");
  fs.appendFileSync(
    logPath,
    "\n==== " + new Date().toISOString() + " companion-launch " + script + " ====\n",
    "utf8"
  );

  // Lanzar PowerShell totalmente separado (sin heredar fd de Electron).
  // start_backend.ps1 escribe solo en backend.log.
  const command =
    "$ErrorActionPreference='Continue'; " +
    "& " +
    psQuote(script) +
    " *>> " +
    psQuote(logPath);

  return new Promise((resolve, reject) => {
    const child = spawn(
      powershellExe(),
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-Command", command],
      {
        cwd: path.dirname(script),
        windowsHide: true,
        detached: true,
        stdio: "ignore",
        env: Object.assign({}, process.env, { PYTHONUNBUFFERED: "1" }),
      }
    );
    child.on("error", (err) => reject(err));
    child.unref();
    backendProc = child;
    if (hooks && hooks.onLine) {
      hooks.onLine("Puente arrancado: " + script);
      hooks.onLine("Log: " + logPath);
    }
    setTimeout(() => resolve({ ok: true, already: false, script, logPath }), 2000);
  });
}

function isInstallRunning() {
  return !!installProc;
}

module.exports = {
  runInstall,
  startBackend,
  isInstallRunning,
  resolveBackendStart,
  syncBackendToApp,
};
