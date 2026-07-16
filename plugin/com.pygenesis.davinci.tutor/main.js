const { app, BrowserWindow } = require("electron");
const path = require("path");

function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 480,
    height: 720,
    minWidth: 380,
    minHeight: 500,
    useContentSize: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      nodeIntegration: true,
      contextIsolation: false,
    },
    autoHideMenuBar: true,
    title: "Pygenesis Resolve Tutor",
  });

  mainWindow.on("close", function () {
    app.quit();
  });

  mainWindow.loadFile(path.join(__dirname, "index.html"));
}

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
