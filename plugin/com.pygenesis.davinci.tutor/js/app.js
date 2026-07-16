(function () {
  "use strict";

  function setResolveIndicator(state, title) {
    var el = document.getElementById("resolve-indicator");
    if (!el) return;

    el.className = "indicator indicator-" + state;
    el.textContent = "Resolve";
    el.title = title || "Estado de Resolve";
  }

  function initResolve() {
    if (typeof window.GetResolveInterface !== "function") {
      setResolveIndicator("error", "Sin conexión con Resolve");
      return false;
    }

    if (window.ResolveContext) {
      window.ResolveContext.invalidateCache();
    }

    try {
      var resolve = window.GetResolveInterface();
      if (resolve) {
        setResolveIndicator("ok", "Conectado a DaVinci Resolve");
        if (window.ChatUI && window.ChatUI.refreshResolveContextDisplay) {
          window.ChatUI.refreshResolveContextDisplay();
        }
        return true;
      }
      setResolveIndicator("error", "Initialize() falló");
      return false;
    } catch (error) {
      setResolveIndicator("error", error.message);
      return false;
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    if (window.ChatUI) {
      window.ChatUI.init();
    }
    initResolve();
  });

  window.addEventListener("beforeunload", function () {
    if (typeof window.CleanupResolveInterface === "function") {
      window.CleanupResolveInterface();
    }
    if (window.ResolveContext) {
      window.ResolveContext.invalidateCache();
    }
  });
})();
