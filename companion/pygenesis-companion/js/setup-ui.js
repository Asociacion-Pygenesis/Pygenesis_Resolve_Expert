(function (global) {
  "use strict";

  var els = {};
  var uninstallLog = null;
  var busy = false;

  function $(id) {
    return document.getElementById(id);
  }

  function statusClass(ok, required) {
    if (ok) return "setup-ok";
    if (required) return "setup-missing";
    return "setup-optional";
  }

  function statusLabel(ok, required) {
    if (ok) return "OK";
    if (required) return "Falta";
    return "Opcional";
  }

  function renderItem(item) {
    var row = document.createElement("div");
    row.className = "setup-item " + statusClass(item.ok, item.required);
    row.setAttribute("data-id", item.id);

    var left = document.createElement("div");
    left.className = "setup-item-main";

    var title = document.createElement("div");
    title.className = "setup-item-title";
    title.textContent = item.label;

    var detail = document.createElement("div");
    detail.className = "setup-item-detail";
    detail.textContent = item.detail || "";

    left.appendChild(title);
    left.appendChild(detail);

    var badge = document.createElement("span");
    badge.className = "setup-badge";
    badge.textContent = statusLabel(item.ok, item.required);

    row.appendChild(left);
    row.appendChild(badge);
    return row;
  }

  function appendLog(line) {
    if (!els.log) return;
    els.log.textContent += line + "\n";
    els.log.scrollTop = els.log.scrollHeight;
  }

  function setBusy(isBusy) {
    busy = isBusy;
    if (els.installBtn) els.installBtn.disabled = isBusy;
    if (els.refreshBtn) els.refreshBtn.disabled = isBusy;
    if (els.backendBtn) els.backendBtn.disabled = isBusy;
    if (els.continueBtn) els.continueBtn.disabled = isBusy;
  }

  function showSetup(show) {
    if (els.setupView) {
      els.setupView.classList.toggle("hidden", !show);
    }
    if (els.chatView) {
      els.chatView.classList.toggle("hidden", show);
    }
  }

  function applyStatus(status) {
    if (!els.list) return;
    els.list.innerHTML = "";
    var order = ["python", "bundle", "runtime", "model", "plugin", "bridge"];
    order.forEach(function (key) {
      if (status[key]) els.list.appendChild(renderItem(status[key]));
    });

    var canContinue = !!(status.readyForChat && status.bridge && status.bridge.ok);
    var canTryChat = !!status.readyForChat;

    if (els.summary) {
      if (canContinue) {
        els.summary.textContent = "Todo listo. Puedes pasar al chat.";
        els.summary.className = "setup-summary setup-summary-ok";
      } else if (canTryChat) {
        els.summary.textContent =
          "Runtime y modelo listos. Arranca el puente y continua.";
        els.summary.className = "setup-summary setup-summary-warn";
      } else {
        els.summary.textContent =
          "Faltan componentes. Pulsa «Instalar lo que falta».";
        els.summary.className = "setup-summary setup-summary-warn";
      }
    }

    if (els.continueBtn) {
      els.continueBtn.disabled = busy || !canTryChat;
      els.continueBtn.textContent = canContinue
        ? "Continuar al chat"
        : "Continuar (arranque el puente si hace falta)";
    }

    if (els.installBtn) {
      els.installBtn.disabled = busy || !(status.bundle && status.bundle.ok);
    }

    return status;
  }

  async function refresh() {
    if (!global.pygenesisSetup) {
      appendLog("API de setup no disponible (preload).");
      return null;
    }
    try {
      var status = await global.pygenesisSetup.getStatus();
      applyStatus(status);
      return status;
    } catch (err) {
      appendLog("Error al comprobar estado: " + err);
      return null;
    }
  }

  async function install() {
    if (!global.pygenesisSetup || busy) return;
    setBusy(true);
    if (els.log) els.log.textContent = "";
    appendLog("Comprobando e instalando componentes...");
    try {
      var result = await global.pygenesisSetup.runInstall();
      if (!result.ok) {
        appendLog("Instalacion incompleta: " + (result.error || "error"));
      }
    } catch (err) {
      appendLog("Error: " + err);
    }
    setBusy(false);
    await refresh();
  }

  async function startBackend() {
    if (!global.pygenesisSetup || busy) return;
    setBusy(true);
    appendLog("Arrancando puente...");
    try {
      var result = await global.pygenesisSetup.startBackend();
      if (!result.ok) {
        appendLog("No se pudo arrancar: " + (result.error || "error"));
      } else {
        appendLog("Esperando health del puente...");
        for (var i = 0; i < 15; i++) {
          await new Promise(function (r) {
            setTimeout(r, 1000);
          });
          var st = await refresh();
          if (st && st.bridge && st.bridge.ok) {
            appendLog("Puente activo.");
            break;
          }
        }
      }
    } catch (err) {
      appendLog("Error: " + err);
    }
    setBusy(false);
    await refresh();
  }

  async function continueToChat() {
    var st = await refresh();
    if (!st || !st.readyForChat) {
      appendLog("Aun faltan runtime o modelo.");
      return;
    }
    if (!st.bridge.ok) {
      await startBackend();
      st = await refresh();
      if (!st || !st.bridge.ok) {
        appendLog("El puente no responde. Revisa el log o arranca Pygenesis Backend.");
        return;
      }
    }
    showSetup(false);
    if (global.ChatUI && global.ChatUI.init) {
      global.ChatUI.init();
    }
  }

  function openSetupFromChat() {
    showSetup(true);
    refresh();
  }

  function init() {
    els.setupView = $("setup-view");
    els.chatView = $("chat-view");
    els.list = $("setup-checklist");
    els.summary = $("setup-summary");
    els.log = $("setup-log");
    els.installBtn = $("setup-install-btn");
    els.refreshBtn = $("setup-refresh-btn");
    els.backendBtn = $("setup-backend-btn");
    els.continueBtn = $("setup-continue-btn");
    els.openSetupBtn = $("open-setup-btn");
    els.pythonHelp = $("setup-python-help");

    if (!els.setupView) return;

    if (global.pygenesisSetup && global.pygenesisSetup.onInstallLog) {
      uninstallLog = global.pygenesisSetup.onInstallLog(appendLog);
    }

    if (els.installBtn) els.installBtn.addEventListener("click", install);
    if (els.refreshBtn) els.refreshBtn.addEventListener("click", refresh);
    if (els.backendBtn) els.backendBtn.addEventListener("click", startBackend);
    if (els.continueBtn) els.continueBtn.addEventListener("click", continueToChat);
    if (els.openSetupBtn) {
      els.openSetupBtn.addEventListener("click", openSetupFromChat);
    }
    if (els.pythonHelp) {
      els.pythonHelp.addEventListener("click", function (e) {
        e.preventDefault();
        if (global.pygenesisSetup) {
          global.pygenesisSetup.openExternal("https://www.python.org/downloads/");
        }
      });
    }

    refresh().then(function (status) {
      if (!status) {
        showSetup(true);
        return;
      }
      var needWizard = !status.readyForChat || !status.bridge.ok;
      showSetup(needWizard);
      if (!needWizard && global.ChatUI && global.ChatUI.init) {
        global.ChatUI.init();
      }
    });
  }

  global.SetupUI = {
    init: init,
    refresh: refresh,
    show: openSetupFromChat,
  };
})(window);
