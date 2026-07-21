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

function resolveBackendStart(packageRoot) {
  // Preferir el backend embebido en Companion (siempre coincide con la version del .exe)
  const pkgStart = path.join(packageRoot, "backend", "scripts", "start_backend.ps1");
  if (packageRoot && fs.existsSync(pkgStart)) return pkgStart;

  const appStart = path.join(pygenesisHome(), "app", "backend", "scripts", "start_backend.ps1");
  if (fs.existsSync(appStart)) return appStart;

  const homeStart = path.join(pygenesisHome(), "Start-Backend.ps1");
  if (fs.existsSync(homeStart)) return homeStart;

  return null;
}

/**
 * Start bridge in background; log to %LOCALAPPDATA%\Pygenesis\logs\backend.log
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
  const logFd = fs.openSync(logPath, "a");
  fs.writeSync(
    logFd,
    "\n==== " + new Date().toISOString() + " start " + script + " ====\n"
  );

  return new Promise((resolve, reject) => {
    const child = spawn(
      powershellExe(),
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script],
      {
        cwd: path.dirname(script),
        windowsHide: true,
        detached: true,
        stdio: ["ignore", logFd, logFd],
        env: process.env,
      }
    );
    child.on("error", (err) => {
      try {
        fs.closeSync(logFd);
      } catch (_) {
        /* ignore */
      }
      reject(err);
    });
    child.unref();
    backendProc = child;
    if (hooks && hooks.onLine) {
      hooks.onLine("Puente arrancado: " + script);
      hooks.onLine("Log: " + logPath);
    }
    setTimeout(() => resolve({ ok: true, already: false, script, logPath }), 1500);
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
};
