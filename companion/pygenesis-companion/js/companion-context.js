(function (global) {
  "use strict";

  var PAGE_LABELS = {
    media: "Media",
    cut: "Cut",
    edit: "Edit",
    fusion: "Fusion",
    color: "Color",
    fairlight: "Fairlight",
    deliver: "Deliver",
  };

  var PAGE_HINTS = {
    media: "Media Pool, importación y organización de clips.",
    cut: "Selección de takes y montaje en Cut.",
    edit: "Timeline, trim, ripple, roll y herramientas de edición.",
    fusion: "Nodos Fusion, efectos y compositing.",
    color: "Scopes, primarias, nodos corrector, qualifiers, LUTs y color management.",
    fairlight: "Mezcla, buses, EQ y loudness.",
    deliver: "Render, codecs y cola de entrega.",
  };

  var STORAGE_KEY = "pygenesis.companion.context";

  var elements = {
    pageSelect: null,
    projectName: null,
    timelineName: null,
  };

  function readStoredContext() {
    try {
      var raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return null;
      return JSON.parse(raw);
    } catch (_) {
      return null;
    }
  }

  function persistContext() {
    if (!elements.pageSelect) return;
    try {
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({
          page: elements.pageSelect.value,
          projectName: elements.projectName ? elements.projectName.value : "",
          timelineName: elements.timelineName ? elements.timelineName.value : "",
        })
      );
    } catch (_) {
      /* localStorage no disponible */
    }
  }

  function restoreStoredContext() {
    var stored = readStoredContext();
    if (!stored || !elements.pageSelect) return;

    if (stored.page && PAGE_LABELS[stored.page]) {
      elements.pageSelect.value = stored.page;
    }
    if (elements.projectName && stored.projectName) {
      elements.projectName.value = stored.projectName;
    }
    if (elements.timelineName && stored.timelineName) {
      elements.timelineName.value = stored.timelineName;
    }
  }

  function getSelectedPage() {
    if (!elements.pageSelect) return "edit";
    var page = String(elements.pageSelect.value || "edit").toLowerCase();
    return PAGE_LABELS[page] ? page : "edit";
  }

  function buildContextBlock(ctx) {
    var lines = [
      "Modo: Companion (contexto manual)",
      "Página activa: " + (ctx.pageLabel || "Desconocida"),
    ];
    if (ctx.projectName) lines.push("Proyecto: " + ctx.projectName);
    if (ctx.timelineName) lines.push("Timeline: " + ctx.timelineName);
    if (ctx.page && PAGE_HINTS[ctx.page]) {
      lines.push("Enfoque en esta página: " + PAGE_HINTS[ctx.page]);
    }
    return lines.join("\n");
  }

  function collectContext() {
    var page = getSelectedPage();
    var pageLabel = PAGE_LABELS[page] || page;
    var projectName =
      elements.projectName && elements.projectName.value.trim()
        ? elements.projectName.value.trim()
        : null;
    var timelineName =
      elements.timelineName && elements.timelineName.value.trim()
        ? elements.timelineName.value.trim()
        : null;

    var ctx = {
      connected: true,
      page: page,
      pageLabel: pageLabel,
      projectName: projectName,
      timelineName: timelineName,
      clipCount: null,
      fps: null,
      connectionReason: "manual",
    };
    ctx.contextoProyecto = buildContextBlock(ctx);
    ctx.summary = [pageLabel, projectName, timelineName].filter(Boolean).join(" · ");
    return ctx;
  }

  var EXPLICIT_PAGE_PATTERNS = {
    media: /\b(?:p[aá]gina\s+)?media(?:\s+pool)?\b/i,
    cut: /\b(?:p[aá]gina\s+)?cut\b/i,
    edit: /\b(?:p[aá]gina\s+)?edit(?:ar|\s+page)?\b/i,
    fusion: /\b(?:p[aá]gina\s+)?fusion\b/i,
    color: /\b(?:p[aá]gina\s+)?color\b/i,
    fairlight: /\b(?:p[aá]gina\s+)?fairlight\b/i,
    deliver: /\b(?:p[aá]gina\s+)?deliver\b/i,
  };

  var TOPIC_SCORE_PATTERNS = [
    {
      page: "fusion",
      pattern:
        /\b(?:fusion|merge\s+node|delta\s+keyer|chroma\s+keyer|keyer|tracker\s+node|composit(?:or|ing)|nodo\s+merge)\b/i,
    },
    {
      page: "color",
      pattern:
        /\b(?:color\s+grad(?:e|ing)|qualifier|lut[s]?|scopes?|primari[ao]s?|secundari[ao]s?|power\s+window|color\s+management|shot\s+match|colortrace|vectorscope|waveform)\b/i,
    },
    {
      page: "fairlight",
      pattern:
        /\b(?:fairlight|bus(?:es)?|loudness|lufs|adr|foley|mezcla\s+de\s+audio|ecualizador|eq\b)\b/i,
    },
    {
      page: "deliver",
      pattern:
        /\b(?:deliver|render\s+queue|exportar|codec[s]?|entrega|renderizar|preset\s+de\s+render|cola\s+de\s+render)\b/i,
    },
    {
      page: "edit",
      pattern:
        /\b(?:timeline|insert|overwrite|replace|compound\s+clip|nested\s+timeline|match\s+frame|marker[s]?|ripple\s+delete|multicam|trim|ripple|roll)\b/i,
    },
    {
      page: "cut",
      pattern: /\b(?:p[aá]gina\s+cut|cut\s+page|source\s+tape)\b/i,
    },
    {
      page: "media",
      pattern: /\b(?:media\s+pool|smart\s+bin[s]?|importar\s+clips?)\b/i,
    },
  ];

  var CONTEXTUAL_QUESTION_RE =
    /\b(?:aqu[ií]|ac[aá])\b|\besta\s+p[aá]gina\b|\ben\s+esta\b|desde\s+aqu[ií]/i;

  var REVIEW_QUESTION_RE =
    /qu[eé]\s+(?:deber[ií]a|tengo\s+que|conviene|hay\s+que)\s+revisar|qu[eé]\s+revisar|revisar\s+(?:en|aqu[ií]|ac[aá])|por\s+d[oó]nde\s+(?:empiezo|empezar|arrancar)|checklist|qu[eé]\s+mirar/i;

  function isContextualQuestion(prompt) {
    return CONTEXTUAL_QUESTION_RE.test(prompt);
  }

  function isReviewQuestion(prompt) {
    return REVIEW_QUESTION_RE.test(prompt);
  }

  function detectQuestionTopic(prompt) {
    var page;
    for (page in EXPLICIT_PAGE_PATTERNS) {
      if (EXPLICIT_PAGE_PATTERNS[page].test(prompt)) return page;
    }

    var scores = {};
    TOPIC_SCORE_PATTERNS.forEach(function (rule) {
      var matches = prompt.match(new RegExp(rule.pattern.source, "gi"));
      if (matches && matches.length) {
        scores[rule.page] = (scores[rule.page] || 0) + matches.length;
      }
    });

    var best = null;
    var bestScore = 0;
    for (page in scores) {
      if (scores[page] > bestScore) {
        bestScore = scores[page];
        best = page;
      }
    }
    return best;
  }

  function analyzePageContext(prompt, ctx) {
    var activePage = ctx && ctx.page ? ctx.page : null;
    var activeLabel = ctx && ctx.pageLabel ? ctx.pageLabel : "Desconocida";
    var esRevision = isReviewQuestion(prompt);

    if (esRevision) {
      var temaRevision = detectQuestionTopic(prompt);
      if (isContextualQuestion(prompt) || !temaRevision) {
        return {
          mode: "contextual",
          tema: activePage,
          temaLabel: activeLabel,
          activePage: activePage,
          activeLabel: activeLabel,
        };
      }
      if (activePage && temaRevision !== activePage) {
        return {
          mode: "mismatch",
          tema: temaRevision,
          temaLabel: PAGE_LABELS[temaRevision] || temaRevision,
          activePage: activePage,
          activeLabel: activeLabel,
        };
      }
      return {
        mode: "matched",
        tema: temaRevision,
        temaLabel: PAGE_LABELS[temaRevision] || temaRevision,
        activePage: activePage,
        activeLabel: activeLabel,
      };
    }

    if (isContextualQuestion(prompt)) {
      return {
        mode: "contextual",
        tema: activePage,
        temaLabel: activeLabel,
        activePage: activePage,
        activeLabel: activeLabel,
      };
    }

    var tema = detectQuestionTopic(prompt);
    if (!activePage) {
      return {
        mode: "general",
        tema: tema,
        temaLabel: tema ? PAGE_LABELS[tema] || tema : null,
        activePage: null,
        activeLabel: activeLabel,
      };
    }
    if (!tema) {
      return {
        mode: "general",
        tema: null,
        temaLabel: null,
        activePage: activePage,
        activeLabel: activeLabel,
      };
    }
    if (tema === activePage) {
      return {
        mode: "matched",
        tema: tema,
        temaLabel: PAGE_LABELS[tema] || tema,
        activePage: activePage,
        activeLabel: activeLabel,
      };
    }
    return {
      mode: "mismatch",
      tema: tema,
      temaLabel: PAGE_LABELS[tema] || tema,
      activePage: activePage,
      activeLabel: activeLabel,
    };
  }

  function getMismatchNotice(prompt, ctx) {
    if (!prompt || !ctx || !ctx.connected) return null;
    var analysis = analyzePageContext(prompt, ctx);
    if (analysis.mode !== "mismatch") return null;
    return (
      "Pregunta sobre " +
      analysis.temaLabel +
      " · Indicaste " +
      analysis.activeLabel +
      " · Respuesta general"
    );
  }

  function notifyContextChanged() {
    persistContext();
    if (global.ChatUI && global.ChatUI.refreshResolveContextDisplay) {
      global.ChatUI.refreshResolveContextDisplay();
    }
    var input = document.getElementById("user-input");
    if (!input || !input.value.trim()) return;

    var notice = document.getElementById("resolve-context-notice");
    if (!notice) return;

    var message = getMismatchNotice(input.value.trim(), collectContext());
    if (message) {
      notice.textContent = message;
      notice.classList.remove("hidden");
    } else {
      notice.textContent = "";
      notice.classList.add("hidden");
    }
  }

  function init() {
    elements.pageSelect = document.getElementById("page-select");
    elements.projectName = document.getElementById("project-name");
    elements.timelineName = document.getElementById("timeline-name");

    restoreStoredContext();

    if (elements.pageSelect) {
      elements.pageSelect.addEventListener("change", notifyContextChanged);
    }
    if (elements.projectName) {
      elements.projectName.addEventListener("input", notifyContextChanged);
      elements.projectName.addEventListener("change", notifyContextChanged);
    }
    if (elements.timelineName) {
      elements.timelineName.addEventListener("input", notifyContextChanged);
      elements.timelineName.addEventListener("change", notifyContextChanged);
    }
  }

  function invalidateCache() {
    /* sin caché de Resolve en modo manual */
  }

  global.ResolveContext = {
    collect: collectContext,
    getContextoProyecto: function () {
      return collectContext().contextoProyecto;
    },
    getSummary: function () {
      return collectContext().summary;
    },
    getConnectionStatus: function () {
      return {
        connected: true,
        reason: "manual",
        message: "Contexto manual (Companion)",
      };
    },
    invalidateCache: invalidateCache,
    analyzePageContext: analyzePageContext,
    getMismatchNotice: getMismatchNotice,
    detectQuestionTopic: detectQuestionTopic,
    init: init,
  };
})(window);
