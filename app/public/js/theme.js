// Theme toggle — three states: 'light', 'dark', or no choice (system).
// Order of preference at runtime: data-theme attribute > localStorage > system.
(function () {
  var STORAGE_KEY = 'madness-theme';
  var root = document.documentElement;

  function systemTheme() {
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }

  function currentTheme() {
    return root.getAttribute('data-theme') || systemTheme();
  }

  function cacheMermaidSources() {
    document.querySelectorAll('.mermaid').forEach(function (el) {
      if (!el.dataset.source) el.dataset.source = el.textContent;
    });
  }

  function renderMermaid() {
    if (!window.mermaid || typeof window.mermaid.initialize !== 'function') return;

    window.mermaid.initialize({
      startOnLoad: false,
      theme: currentTheme() === 'dark' ? 'dark' : 'default'
    });

    if (typeof window.mermaid.run !== 'function') return;

    document.querySelectorAll('.mermaid').forEach(function (el) {
      if (!el.dataset.source) return;

      el.removeAttribute('data-processed');
      el.textContent = el.dataset.source;
    });

    var result = window.mermaid.run({ querySelector: '.mermaid' });
    if (result && typeof result.catch === 'function') {
      result.catch(function (e) {
        if (window.console && console.error) console.error('Mermaid failed to rerender', e);
      });
    }
  }

  function applyTheme(next) {
    if (next === 'system') {
      root.removeAttribute('data-theme');
      try { localStorage.removeItem(STORAGE_KEY); } catch (e) {}
    } else {
      root.setAttribute('data-theme', next);
      try { localStorage.setItem(STORAGE_KEY, next); } catch (e) {}
    }

    renderMermaid();
  }

  function toggle(e) {
    if (e) e.preventDefault();
    var next = currentTheme() === 'dark' ? 'light' : 'dark';
    applyTheme(next);
  }

  document.querySelectorAll('.theme-toggle, .floating-theme-toggle').forEach(function (el) {
    el.addEventListener('click', toggle);
  });

  cacheMermaidSources();

  // React to system preference changes only when the user hasn't pinned a choice.
  if (window.matchMedia) {
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    var handler = function () {
      var stored;
      try { stored = localStorage.getItem(STORAGE_KEY); } catch (e) {}
      if (stored !== 'light' && stored !== 'dark') applyTheme('system');
    };
    if (mq.addEventListener) mq.addEventListener('change', handler);
    else if (mq.addListener) mq.addListener(handler);
  }
})();
