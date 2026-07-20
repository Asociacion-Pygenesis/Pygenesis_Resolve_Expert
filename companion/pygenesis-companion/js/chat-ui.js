(function (global) {
  "use strict";

  var elements = {};
  var isLoading = false;
  var bridgeAvailable = false;
  var WORD_DELAY_MS = 32;

  function configureMarked() {
    if (typeof marked === "undefined") return;
    marked.setOptions({
      breaks: true,
      gfm: true,
      headerIds: false,
      mangle: false,
    });
  }

  function renderMarkdown(text) {
    if (typeof marked !== "undefined") {
      return marked.parse(text);
    }
    return "<p>" + escapeHtml(text).replace(/\n/g, "<br>") + "</p>";
  }

  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function scrollToBottom() {
    if (!elements.messages) return;
    elements.messages.scrollTop = elements.messages.scrollHeight;
  }

  function setSendEnabled(enabled) {
    if (elements.sendBtn) {
      elements.sendBtn.disabled = !enabled || isLoading || !bridgeAvailable;
    }
    if (elements.input) {
      elements.input.disabled = isLoading || !bridgeAvailable;
    }
  }

  function showConnectionBanner(show, text) {
    if (!elements.banner) return;
    if (show) {
      elements.banner.classList.remove("hidden");
      if (text && elements.bannerText) {
        elements.bannerText.textContent = text;
      }
    } else {
      elements.banner.classList.add("hidden");
    }
  }

  function appendMessage(role, htmlContent, extraClass) {
    var wrapper = document.createElement("div");
    wrapper.className =
      "message message-" + role + (extraClass ? " " + extraClass : "");

    var label = document.createElement("div");
    label.className = "message-label";
    label.textContent = role === "user" ? "Tú" : "Pygenesis";

    var body = document.createElement("div");
    body.className = "message-body markdown-body";
    body.innerHTML = htmlContent;

    wrapper.appendChild(label);
    wrapper.appendChild(body);
    elements.messages.appendChild(wrapper);
    scrollToBottom();
    return wrapper;
  }

  function appendUserMessage(text) {
    return appendMessage("user", "<p>" + escapeHtml(text) + "</p>");
  }

  function appendAssistantMessage(markdownText) {
    return appendMessage("assistant", renderMarkdown(markdownText));
  }

  function appendErrorMessage(text) {
    return appendMessage("assistant", "<p>" + escapeHtml(text) + "</p>", "message-error");
  }

  function createStreamingAssistantMessage() {
    var wrapper = document.createElement("div");
    wrapper.className = "message message-assistant message-streaming";
    wrapper.id = "streaming-message";

    var label = document.createElement("div");
    label.className = "message-label";
    label.textContent = "Pygenesis";

    var body = document.createElement("div");
    body.className = "message-body markdown-body typing-plain";
    body.textContent = "";

    wrapper.appendChild(label);
    wrapper.appendChild(body);
    elements.messages.appendChild(wrapper);
    scrollToBottom();

    return {
      wrapper: wrapper,
      body: body,
      displayed: "",
      queue: [],
      draining: false,
      done: false,
      finalizePromise: null,
      resolveFinalize: null,
    };
  }

  function splitIntoWordUnits(text) {
    if (!text) return [];
    return text.match(/\S+\s*|\s+/g) || [text];
  }

  function enqueueText(streamState, chunk) {
    var units = splitIntoWordUnits(chunk);
    for (var i = 0; i < units.length; i++) {
      streamState.queue.push(units[i]);
    }
    if (!streamState.draining) {
      drainWordQueue(streamState);
    }
  }

  function drainWordQueue(streamState) {
    streamState.draining = true;

    function step() {
      if (streamState.queue.length > 0) {
        streamState.displayed += streamState.queue.shift();
        streamState.body.textContent = streamState.displayed;
        scrollToBottom();
        setTimeout(step, WORD_DELAY_MS);
        return;
      }

      streamState.draining = false;
      if (streamState.done && streamState.resolveFinalize) {
        streamState.resolveFinalize();
        streamState.resolveFinalize = null;
      }
    }

    step();
  }

  function waitForTypingComplete(streamState) {
    if (!streamState.draining && streamState.queue.length === 0) {
      return Promise.resolve();
    }
    streamState.finalizePromise = streamState.finalizePromise || new Promise(function (resolve) {
      streamState.resolveFinalize = resolve;
    });
    return streamState.finalizePromise;
  }

  function finalizeStreamingMessage(streamState, finalText) {
    streamState.wrapper.classList.remove("message-streaming");
    streamState.body.classList.remove("typing-plain");
    streamState.body.innerHTML = renderMarkdown(finalText || streamState.displayed);
    streamState.wrapper.removeAttribute("id");
    scrollToBottom();
  }

  async function refreshConnection() {
    if (!global.ChatAPI) return;

    var health = await global.ChatAPI.checkBridgeHealth();
    bridgeAvailable = health.ok;

    if (!health.bridgeUp) {
      showConnectionBanner(
        true,
        "Puente de inferencia no disponible en " +
          global.ChatAPI.BACKEND_BASE +
          ". " +
          (health.error || "Arranca el backend con .\\start_backend.ps1")
      );
      if (elements.modelStatus) {
        elements.modelStatus.textContent = "Puente: desconectado";
      }
    } else if (!health.modelLoaded) {
      showConnectionBanner(
        true,
        health.error ||
          "Modelo no cargado. Ejecuta installer\\install_pygenesis.ps1 o coloca el GGUF en %LOCALAPPDATA%\\Pygenesis\\models\\"
      );
      if (elements.modelStatus) {
        elements.modelStatus.textContent = "Puente: sin modelo";
      }
    } else {
      showConnectionBanner(false);
      if (elements.modelStatus) {
        var rag = health.ragActivo ? " · RAG activo" : "";
        var gpu = health.backend ? " · " + health.backend : "";
        elements.modelStatus.textContent =
          "Puente: " + (health.modelo || "pygenesis-resolve") + gpu + rag;
      }
    }

    setSendEnabled(true);
  }

  function refreshResolveContextDisplay() {
    var el = document.getElementById("resolve-context-text");
    if (!el || !global.ResolveContext) return;
    var ctx = global.ResolveContext.collect();
    if (!ctx.connected) {
      var msg = ctx.summary || "Resolve no conectado";
      if (ctx.connectionReason === "missing_bridge") {
        msg = "Falta WorkflowIntegration.node — ejecuta install_plugin.ps1 con Resolve cerrado";
      }
      el.textContent = "Contexto: " + msg;
      refreshPageMismatchNotice("");
      return;
    }
    el.textContent = "Contexto: " + (ctx.summary || "—");
    el.title = ctx.contextoProyecto || ctx.summary;
    if (elements.input) {
      refreshPageMismatchNotice(elements.input.value.trim());
    }
  }

  function refreshPageMismatchNotice(promptText) {
    var notice = document.getElementById("resolve-context-notice");
    if (!notice || !global.ResolveContext || !global.ResolveContext.getMismatchNotice) return;

    if (!promptText) {
      notice.classList.add("hidden");
      notice.textContent = "";
      return;
    }

    var ctx = global.ResolveContext.collect();
    var message = global.ResolveContext.getMismatchNotice(promptText, ctx);
    if (message) {
      notice.textContent = message;
      notice.classList.remove("hidden");
    } else {
      notice.textContent = "";
      notice.classList.add("hidden");
    }
  }

  async function sendMessage() {
    if (!elements.input || isLoading || !bridgeAvailable) return;

    var text = elements.input.value.trim();
    if (!text) return;

    elements.input.value = "";
    appendUserMessage(text);

    isLoading = true;
    setSendEnabled(false);

    var streamState = createStreamingAssistantMessage();
    if (global.ResolveContext) {
      global.ResolveContext.invalidateCache();
    }
    var ctx = global.ResolveContext ? global.ResolveContext.collect() : null;
    var contextoProyecto = ctx ? ctx.contextoProyecto : "";
    refreshResolveContextDisplay();

    await new Promise(function (resolve) {
      global.ChatAPI.consultarPuenteStream(text, contextoProyecto, {
        onToken: function (token) {
          enqueueText(streamState, token);
        },
        onDone: function (finalText) {
          if (!streamState.displayed && finalText) {
            enqueueText(streamState, finalText);
          }
          streamState.done = true;
          waitForTypingComplete(streamState).then(function () {
            finalizeStreamingMessage(streamState, finalText);
            resolve();
          });
          if (!streamState.draining && streamState.queue.length === 0 && streamState.resolveFinalize) {
            streamState.resolveFinalize();
          }
        },
        onError: function (error) {
          streamState.wrapper.remove();
          var msg =
            error.name === "AbortError"
              ? "La consulta tardó demasiado. Comprueba que el puente sigue activo."
              : "Error al consultar el puente: " + (error.message || "desconocido");
          appendErrorMessage(msg);
          resolve();
        },
      });
    });

    await refreshConnection();
    isLoading = false;
    setSendEnabled(true);
    if (elements.input) elements.input.focus();
  }

  function handleInputKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      sendMessage();
    }
  }

  var initialized = false;

  function init() {
    if (initialized) {
      refreshConnection();
      refreshResolveContextDisplay();
      return;
    }
    initialized = true;

    elements.messages = document.getElementById("chat-messages");
    elements.input = document.getElementById("user-input");
    elements.sendBtn = document.getElementById("send-btn");
    elements.banner = document.getElementById("connection-banner");
    elements.bannerText = document.getElementById("connection-banner-text");
    elements.modelStatus = document.getElementById("model-status");
    elements.retryBtn = document.getElementById("connection-retry");

    configureMarked();

    if (elements.sendBtn) {
      elements.sendBtn.addEventListener("click", sendMessage);
    }
    if (elements.input) {
      elements.input.addEventListener("keydown", handleInputKeydown);
      elements.input.addEventListener("input", function () {
        setSendEnabled(elements.input.value.trim().length > 0);
        refreshPageMismatchNotice(elements.input.value.trim());
      });
    }
    if (elements.retryBtn) {
      elements.retryBtn.addEventListener("click", refreshConnection);
    }

    refreshConnection();
    setInterval(refreshConnection, 30000);
    setInterval(refreshResolveContextDisplay, 5000);
    refreshResolveContextDisplay();
  }

  global.ChatUI = {
    init: init,
    refreshConnection: refreshConnection,
    refreshResolveContextDisplay: refreshResolveContextDisplay,
    appendAssistantMessage: appendAssistantMessage,
  };
})(window);
