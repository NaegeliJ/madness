// Highlights the current section in the floating table-of-contents pane
// while scrolling. Progressive enhancement: the pane's links work without it.
//
// The active section is the *last* heading that has scrolled above a small
// threshold near the top of the viewport. Evaluating every heading on each
// scroll frame makes this deterministic: it never skips a section and never
// jumps to the next one when several short sections are on screen at once.
(function () {
  var pane = document.querySelector('.toc-pane');
  if (!pane) return;

  var links = Array.prototype.slice.call(pane.querySelectorAll('a[href^="#"]'));
  if (!links.length) return;

  // Link + heading pairs, in document order.
  var entries = [];
  links.forEach(function (link) {
    var id = decodeURIComponent(link.getAttribute('href').slice(1));
    var heading = document.getElementById(id);
    if (heading) entries.push({ link: link, heading: heading });
  });
  if (!entries.length) return;

  // Keep the scroll-spy line just below the headings' scroll-margin-top (set
  // in fork.css, e.g. 8vh), so a heading counts as "current" the moment a
  // click lands it near the top. Read from the CSS so the two never drift.
  function threshold() {
    var margin = parseFloat(getComputedStyle(entries[0].heading).scrollMarginTop) || 0;
    return margin + 12;
  }

  var current = null;
  function setActive(link) {
    if (current === link) return;
    if (current) current.classList.remove('active');
    if (link) link.classList.add('active');
    current = link;
  }

  function atBottom() {
    return window.innerHeight + window.scrollY >=
      document.documentElement.scrollHeight - 2;
  }

  function update() {
    if (atBottom()) {
      setActive(entries[entries.length - 1].link);
      return;
    }

    var line = threshold();
    var active = entries[0];
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].heading.getBoundingClientRect().top <= line) {
        active = entries[i];
      } else {
        break;
      }
    }
    setActive(active.link);
  }

  var ticking = false;
  function onScroll() {
    if (ticking) return;
    ticking = true;
    window.requestAnimationFrame(function () {
      update();
      ticking = false;
    });
  }

  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', onScroll);

  // Briefly flash the target heading so the eye catches where the jump
  // landed. Restart-safe when the same entry is clicked repeatedly.
  function flash(heading) {
    heading.classList.remove('toc-flash');
    void heading.offsetWidth; // force reflow so the animation replays
    heading.classList.add('toc-flash');
    heading.addEventListener('animationend', function handler() {
      heading.classList.remove('toc-flash');
      heading.removeEventListener('animationend', handler);
    });
  }

  // Highlight the pane entry immediately on click, before the scroll settles.
  entries.forEach(function (entry) {
    entry.link.addEventListener('click', function () {
      setActive(entry.link);
      flash(entry.heading);
    });
  });

  update();
})();
