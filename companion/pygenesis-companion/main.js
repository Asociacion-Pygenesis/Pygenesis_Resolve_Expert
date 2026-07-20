"use strict";

const { app, BrowserWindow, ipcMain, shell } = require("electron");
const path = require("path");
const fs = require("fs");
const { runDiagnostics } = require("./setup/diagnostics");
const { runInstall, startBackend } = require("./setup/installer");

let mainWindow = null;

function findPackageRoot() {
  const candidates = [];

  if (app.isPackaged) {
    candidates.push(process.resourcesPath);
    candidates.push(path.join(process.resourcesPath, ".."));
    // Release ZIP layout: .../PygenesisResolveExpert/companion/dist/win-unpacked/resources
    candidates.push(path.resolve(process.resourcesPath, "..", "..", "..", ".."));
    candidates.push(path.resolve(path.dirname(process.execPath), "..", "..", ".."));
  }

  // Dev: companion/pygenesis-companion → repo root
  candidates.push(path.resolve(__dirname, "..", ".."));

  // After install: full payload under LocalAppData\Pygenesis\app
  if (process.env.LOCALAPPDATA) {
    candidates.push(path.join(process.env.LOCALAPPDATA, "Pygenesis", "app"));
  }

  for (const c of candidates) {
    try {
      if (fs.existsSync(path.join(c, "installer", "install_pygenesis.ps1"))) {
        return c;
      }
    } catch (_) {
      /* next */
    }
  }
  return candidates[0];
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 560,
    height: 820,
    minWidth: 420,
    minHeight: 600,
    useContentSize: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      nodeIntegration: false,
      contextIsolation: true,
    },
    autoHideMenuBar: true,
    title: "Pygenesis Companion",
  });

  mainWindow.on("close", function () {
    app.quit();
  });

  mainWindow.loadFile(path.join(__dirname, "index.html"));
}

function sendLog(line) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send("setup:installLog", line);
  }
}

ipcMain.handle("setup:getStatus", async () => {
  const root = findPackageRoot();
  return runDiagnostics(root);
});

ipcMain.handle("setup:runInstall", async () => {
  const root = findPackageRoot();
  try {
    sendLog("Iniciando instalacion desde: " + root);
    const result = await runInstall(root, {
      onLine: (line) => sendLog(line),
    });
    sendLog("Instalacion completada.");
    return { ok: true, result };
  } catch (err) {
    sendLog("ERROR: " + (err && err.message ? err.message : String(err)));
    return { ok: false, error: err && err.message ? err.message : String(err) };
  }
});

ipcMain.handle("setup:startBackend", async () => {
  const root = findPackageRoot();
  try {
    const result = await startBackend(root, {
      onLine: (line) => sendLog(line),
    });
    return { ok: true, result };
  } catch (err) {
    return { ok: false, error: err && err.message ? err.message : String(err) };
  }
});

ipcMain.handle("setup:openExternal", async (_e, url) => {
  if (typeof url === "string" && /^https?:\/\//i.test(url)) {
    await shell.openExternal(url);
    return { ok: true };
  }
  return { ok: false };
});

app.on("ready", createWindow);

app.on("window-all-closed", function () {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("activate", function () {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
