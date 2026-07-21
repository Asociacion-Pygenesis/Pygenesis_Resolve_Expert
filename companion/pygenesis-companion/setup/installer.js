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
 * Start bridge via .cmd + start (Electron spawn -Command/*>> no ejecuta el .ps1 en Windows).
 */
function startBackend(packageRoot, hooks) {
  const script = resolveBackendStart(packageRoot);
  if (!script) {
    return Promise.reject(new Error("No se encontro start_backend.ps1. Instala primero."));
  }
  if (backendProc && !backendProc.killed) {
    return Promise.resolve({ ok: true, already: true, script });
  }

  const home = pygenesisHome();
  const logDir = path.join(home, "logs");
  fs.mkdirSync(logDir, { recursive: true });
  const logPath = path.join(logDir, "backend.log");
  const cmdPath = path.join(home, "Start-Backend-Hidden.cmd");
  const psExe = powershellExe();

  fs.appendFileSync(
    logPath,
    "\n==== " + new Date().toISOString() + " companion-launch " + script + " ====\n",
    "utf8"
  );

  // Launcher .cmd: si esto no aparece en el log, ni siquiera arranco cmd/start.
  const cmdBody =
    "@echo off\r\n" +
    "echo [" + "%date% %time%" + "] cmd-launcher OK>> \"" + logPath + "\"\r\n" +
    "\"" + psExe + "\" -NoProfile -ExecutionPolicy Bypass -File \"" + script + "\" >> \"" + logPath + "\" 2>&1\r\n" +
    "echo [" + "%date% %time%" + "] powershell-exit %ERRORLEVEL%>> \"" + logPath + "\"\r\n";
  fs.writeFileSync(cmdPath, cmdBody, "utf8");

  // Actualizar Start-Backend.ps1 del home para el atajo del menu Inicio
  try {
    fs.writeFileSync(
      path.join(home, "Start-Backend.ps1"),
      "#Requires -Version 5.1\r\n& '" + script.replace(/'/g, "''") + "' @args\r\n",
      "utf8"
    );
  } catch (_) {
    /* ignore */
  }

  const cmdExe = process.env.SystemRoot
    ? path.join(process.env.SystemRoot, "System32", "cmd.exe")
    : "cmd.exe";

  return new Promise((resolve, reject) => {
    // start "" = titulo vacio; /MIN ventana minimizada independiente de Electron
    const child = spawn(
      cmdExe,
      ["/c", "start", "/MIN", "", cmdPath],
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
      hooks.onLine("Puente arrancado via: " + cmdPath);
      hooks.onLine("Script: " + script);
      hooks.onLine("Log: " + logPath);
    }

    // Verificar que el launcher escribio en el log (si no, Electron no logro spawn)
    setTimeout(() => {
      let launched = false;
      try {
        const text = fs.readFileSync(logPath, "utf8");
        launched = /cmd-launcher OK|start_backend\.ps1 begin/i.test(text);
      } catch (_) {
        launched = false;
      }
      if (!launched && hooks && hooks.onLine) {
        hooks.onLine(
          "AVISO: no se ve actividad en el log. Prueba menu Inicio → Pygenesis Backend."
        );
      }
      resolve({ ok: true, already: false, script, logPath, cmdPath, launched });
    }, 2500);
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
