"use strict";

const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("pygenesisSetup", {
  getStatus: () => ipcRenderer.invoke("setup:getStatus"),
  runInstall: () => ipcRenderer.invoke("setup:runInstall"),
  startBackend: () => ipcRenderer.invoke("setup:startBackend"),
  onInstallLog: (cb) => {
    const handler = (_event, line) => cb(line);
    ipcRenderer.on("setup:installLog", handler);
    return () => ipcRenderer.removeListener("setup:installLog", handler);
  },
  openExternal: (url) => ipcRenderer.invoke("setup:openExternal", url),
});
