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

  function applyTheme(next) {
    if (next === 'system') {
      root.removeAttribute('data-theme');
      try { localStorage.removeItem(STORAGE_KEY); } catch (e) {}
    } else {
      root.setAttribute('data-theme', next);
      try { localStorage.setItem(STORAGE_KEY, next); } catch (e) {}
    }
    if (window.mermaid && typeof window.mermaid.initialize === 'function') {
      // Mermaid already rendered. Re-init won't re-style existing SVGs, but
      // any subsequent renders will pick up the new theme. Good enough.
      window.mermaid.initialize({
        startOnLoad: false,
        theme: currentTheme() === 'dark' ? 'dark' : 'default'
      });
    }
  }

  function toggle(e) {
    if (e) e.preventDefault();
    var next = currentTheme() === 'dark' ? 'light' : 'dark';
    applyTheme(next);
  }

  document.querySelectorAll('.theme-toggle, .floating-theme-toggle').forEach(function (el) {
    el.addEventListener('click', toggle);
  });

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
