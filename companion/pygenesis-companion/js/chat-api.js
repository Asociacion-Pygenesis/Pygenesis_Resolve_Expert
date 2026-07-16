(function (global) {
  "use strict";

  const BACKEND_BASE = "http://localhost:8000";
  const REQUEST_TIMEOUT_MS = 120000;

  function fetchWithTimeout(url, options, timeoutMs) {
    const controller = new AbortController();
    const timer = setTimeout(function () {
      controller.abort();
    }, timeoutMs);

    return fetch(url, Object.assign({}, options || {}, { signal: controller.signal }))
      .finally(function () {
        clearTimeout(timer);
      });
  }

  function parseSseChunk(buffer) {
    const events = [];
    const parts = buffer.split("\n\n");
    const rest = parts.pop() || "";

    parts.forEach(function (block) {
      const lines = block.split("\n");
      let dataLine = "";
      lines.forEach(function (line) {
        if (line.indexOf("data:") === 0) {
          dataLine += line.slice(5).trim();
        }
      });
      if (!dataLine) return;
      try {
        events.push(JSON.parse(dataLine));
      } catch (_) {
        /* línea SSE incompleta o inválida */
      }
    });

    return { events: events, rest: rest };
  }

  async function checkBridgeHealth() {
    try {
      const response = await fetchWithTimeout(
        BACKEND_BASE + "/health",
        { method: "GET" },
        5000
      );
      if (!response.ok) {
        return { ok: false, error: "El puente respondió con error " + response.status };
      }

      const data = await response.json();
      var bridgeUp = data.status === "ok" || data.status === "degraded";
      var modelLoaded = data.model_loaded !== false;
      var error = null;
      if (!bridgeUp) {
        error = "Estado del puente: " + (data.status || "desconocido");
      } else if (!modelLoaded) {
        error =
          "Puente activo pero el modelo no está cargado. " +
          (data.error || "Ejecuta installer\\install_pygenesis.ps1 o coloca el GGUF en %LOCALAPPDATA%\\Pygenesis\\models\\");
      }
      return {
        ok: bridgeUp && modelLoaded,
        bridgeUp: bridgeUp,
        modelLoaded: modelLoaded,
        modelo: data.modelo || "pygenesis-resolve",
        backend: data.backend || null,
        ragActivo: !!data.rag_activo,
        error: error,
      };
    } catch (error) {
      const message =
        error.name === "AbortError"
          ? "Tiempo de espera agotado al contactar el puente"
          : error.message || "No se pudo conectar con el puente de inferencia";
      return { ok: false, error: message };
    }
  }

  async function consultarPuente(prompt, contextoProyecto) {
    const response = await fetchWithTimeout(
      BACKEND_BASE + "/consultar",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          prompt: prompt,
          contexto_proyecto: contextoProyecto || "",
          modo_json: false,
        }),
      },
      REQUEST_TIMEOUT_MS
    );

    if (!response.ok) {
      throw new Error("El puente respondió con error " + response.status);
    }

    const data = await response.json();
    return data.respuesta || "";
  }

  async function consultarPuenteStream(prompt, contextoProyecto, handlers) {
    const onToken = handlers.onToken || function () {};
    const onDone = handlers.onDone || function () {};
    const onError = handlers.onError || function () {};

    let response;
    try {
      response = await fetchWithTimeout(
        BACKEND_BASE + "/consultar/stream",
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            prompt: prompt,
            contexto_proyecto: contextoProyecto || "",
            modo_json: false,
          }),
        },
        REQUEST_TIMEOUT_MS
      );
    } catch (error) {
      onError(error);
      return;
    }

    if (response.status === 404) {
      try {
        const texto = await consultarPuente(prompt, contextoProyecto);
        onDone(texto, 0);
      } catch (error) {
        onError(error);
      }
      return;
    }

    if (!response.ok || !response.body) {
      onError(new Error("El puente respondió con error " + response.status));
      return;
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    try {
      while (true) {
        const chunk = await reader.read();
        if (chunk.done) break;

        buffer += decoder.decode(chunk.value, { stream: true });
        const parsed = parseSseChunk(buffer);
        buffer = parsed.rest;

        parsed.events.forEach(function (event) {
          if (event.token) {
            onToken(event.token);
          }
          if (event.done) {
            onDone(event.respuesta || "", event.fragmentos_usados || 0);
          }
        });
      }
    } catch (error) {
      onError(error);
    }
  }

  global.ChatAPI = {
    BACKEND_BASE: BACKEND_BASE,
    checkBridgeHealth: checkBridgeHealth,
    consultarPuente: consultarPuente,
    consultarPuenteStream: consultarPuenteStream,
  };
})(window);
