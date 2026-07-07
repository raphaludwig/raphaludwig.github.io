(function () {
  'use strict';

  // PROVISIONAL — delete this file (and its include in _quarto.yml, and the
  // palette blocks in assets/css/theme.scss) once Raphael picks a winning
  // palette. Persists the chosen palette across pages via localStorage so
  // navbar/footer consistency can be checked on every page, not just home.

  var STORAGE_KEY = 'site-palette';
  var PALETTES = [
    { id: 'p3', label: 'Sage + slate (favorite)', swatch: '#84a98c' },
    { id: 'p1', label: 'Purple-gray', swatch: '#6c698d' },
    { id: 'p2', label: 'Warm + terracotta', swatch: '#a5766a' },
    { id: 'c1', label: 'Graphite + teal (original)', swatch: '#14b8a6' },
    { id: 'c2', label: 'Navy + slate', swatch: '#3b82f6' },
    { id: 'c3', label: 'Deep forest', swatch: '#5fd39b' }
  ];
  var DEFAULT_PALETTE = 'p3';

  function getStored() {
    var v = localStorage.getItem(STORAGE_KEY);
    return PALETTES.some(function (p) { return p.id === v; }) ? v : DEFAULT_PALETTE;
  }

  function apply(id) {
    document.documentElement.setAttribute('data-palette', id);
    localStorage.setItem(STORAGE_KEY, id);
  }

  // Apply immediately (before DOMContentLoaded) to avoid a flash of the default palette.
  apply(getStored());

  document.addEventListener('DOMContentLoaded', function () {
    var box = document.createElement('div');
    box.id = 'palette-switcher';
    box.setAttribute('role', 'group');
    box.setAttribute('aria-label', 'Preview color palette (temporary)');

    var current = getStored();

    PALETTES.forEach(function (p) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.style.background = p.swatch;
      btn.title = p.label;
      btn.setAttribute('aria-label', p.label);
      btn.setAttribute('aria-pressed', String(p.id === current));
      btn.addEventListener('click', function () {
        apply(p.id);
        Array.prototype.forEach.call(box.children, function (b, i) {
          b.setAttribute('aria-pressed', String(PALETTES[i].id === p.id));
        });
      });
      box.appendChild(btn);
    });

    document.body.appendChild(box);
  });
})();
