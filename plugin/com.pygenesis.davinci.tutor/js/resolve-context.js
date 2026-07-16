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

  var resolveCache = null;

  function getResolve() {
    if (resolveCache) return resolveCache;
    if (typeof global.GetResolveInterface !== "function") return null;
    try {
      resolveCache = global.GetResolveInterface();
      return resolveCache;
    } catch (_) {
      return null;
    }
  }

  function getConnectionStatus() {
    if (typeof global.GetResolveInterface !== "function") {
      return {
        connected: false,
        reason: "missing_bridge",
        message: "Falta WorkflowIntegration.node en la instalación del plugin",
      };
    }
    try {
      var resolve = getResolve();
      if (resolve) {
        return { connected: true, reason: "ok", message: "" };
      }
      return {
        connected: false,
        reason: "init_failed",
        message: "Resolve no inicializó el plugin (cierra y reabre la ventana)",
      };
    } catch (error) {
      return {
        connected: false,
        reason: "error",
        message: error.message || "Error al conectar con Resolve",
      };
    }
  }

  function safeName(obj) {
    if (!obj) return null;
    try {
      var name = obj.GetName();
      return name ? String(name) : null;
    } catch (_) {
      return null;
    }
  }

  function countTimelineClips(timeline) {
    if (!timeline) return null;
    try {
      var total = 0;
      var tracks = timeline.GetTrackCount("video");
      if (!tracks || tracks < 1) return 0;
      for (var t = 1; t <= tracks; t++) {
        var items = timeline.GetItemListInTrack("video", t);
        if (items && items.length) total += items.length;
      }
      return total;
    } catch (_) {
      return null;
    }
  }

  function getTimelineFps(project, timeline) {
    try {
      if (timeline && typeof timeline.GetSetting === "function") {
        var fps = timeline.GetSetting("timelineFrameRate");
        if (fps) return String(fps);
      }
      if (project && typeof project.GetSetting === "function") {
        var projectFps = project.GetSetting("timelineFrameRate");
        if (projectFps) return String(projectFps);
      }
    } catch (_) {
      /* setting no disponible en esta versión */
    }
    return null;
  }

  function getTimelineDuration(timeline) {
    if (!timeline) return null;
    try {
      var start = timeline.GetStartFrame();
      var end = timeline.GetEndFrame();
      if (typeof start === "number" && typeof end === "number" && end >= start) {
        return end - start + 1;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  var PAGE_HINTS = {
    media: "Media Pool, importación y organización de clips.",
    cut: "Selección de takes y montaje en Cut.",
    edit: "Timeline, trim, ripple, roll y herramientas de edición.",
    fusion: "Nodos Fusion, efectos y compositing.",
    color: "Scopes, primarias, nodos corrector, qualifiers, LUTs y color management.",
    fairlight: "Mezcla, buses, EQ y loudness.",
    deliver: "Render, codecs y cola de entrega.",
  };

  function buildContextBlock(ctx) {
    var lines = ["Página activa: " + (ctx.pageLabel || "Desconocida")];
    if (ctx.projectName) lines.push("Proyecto: " + ctx.projectName);
    if (ctx.timelineName) lines.push("Timeline: " + ctx.timelineName);
    if (ctx.clipCount != null) lines.push("Clips de vídeo en timeline: " + ctx.clipCount);
    if (ctx.fps) lines.push("Frame rate: " + ctx.fps + " fps");
    if (ctx.page && PAGE_HINTS[ctx.page]) {
      lines.push("Enfoque en esta página: " + PAGE_HINTS[ctx.page]);
    }
    return lines.join("\n");
  }

  function collectContext() {
    var status = getConnectionStatus();
    var empty = {
      connected: false,
      page: null,
      pageLabel: null,
      projectName: null,
      timelineName: null,
      summary: status.message || "Sin contexto de Resolve",
      contextoProyecto: "",
      connectionReason: status.reason,
    };

    if (!status.connected) return empty;

    var resolve = getResolve();
    if (!resolve) return empty;

    try {
      var page = resolve.GetCurrentPage();
      if (page) page = String(page).toLowerCase();

      var projectName = null;
      var timelineName = null;
      var clipCount = null;
      var fps = null;
      var pm = resolve.GetProjectManager();
      var project = null;
      var timeline = null;
      if (pm) {
        project = pm.GetCurrentProject();
        projectName = safeName(project);
        if (project) {
          timeline = project.GetCurrentTimeline();
          timelineName = safeName(timeline);
          clipCount = countTimelineClips(timeline);
          fps = getTimelineFps(project, timeline);
        }
      }

      var pageLabel = PAGE_LABELS[page] || page || "Desconocida";

      var ctx = {
        connected: true,
        page: page,
        pageLabel: pageLabel,
        projectName: projectName,
        timelineName: timelineName,
        clipCount: clipCount,
        fps: fps,
      };
      ctx.contextoProyecto = buildContextBlock(ctx);
      ctx.summary = [pageLabel, projectName, timelineName].filter(Boolean).join(" · ");

      return ctx;
    } catch (_) {
      return {
        connected: true,
        page: null,
        pageLabel: null,
        projectName: null,
        timelineName: null,
        summary: "Resolve conectado",
        contextoProyecto: "",
      };
    }
  }

  function getContextoProyecto() {
    return collectContext().contextoProyecto;
  }

  function getSummary() {
    return collectContext().summary;
  }

  function invalidateCache() {
    resolveCache = null;
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
      " · Estás en " +
      analysis.activeLabel +
      " · Respuesta general"
    );
  }

  global.ResolveContext = {
    collect: collectContext,
    getContextoProyecto: getContextoProyecto,
    getSummary: getSummary,
    getConnectionStatus: getConnectionStatus,
    invalidateCache: invalidateCache,
    analyzePageContext: analyzePageContext,
    getMismatchNotice: getMismatchNotice,
    detectQuestionTopic: detectQuestionTopic,
  };
})(window);
