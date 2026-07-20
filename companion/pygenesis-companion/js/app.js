(function () {
  "use strict";

  function setCompanionIndicator() {
    var el = document.getElementById("resolve-indicator");
    if (!el) return;

    el.className = "indicator indicator-companion";
    el.textContent = "Manual";
    el.title =
      "Contexto manual — selecciona la pagina en la que trabajas en Resolve";
  }

  document.addEventListener("DOMContentLoaded", function () {
    if (window.ResolveContext && window.ResolveContext.init) {
      window.ResolveContext.init();
    }
    // ChatUI.init se llama desde SetupUI cuando el entorno esta listo
    if (window.SetupUI && window.SetupUI.init) {
      window.SetupUI.init();
    } else if (window.ChatUI) {
      window.ChatUI.init();
    }
    setCompanionIndicator();
  });
})();
