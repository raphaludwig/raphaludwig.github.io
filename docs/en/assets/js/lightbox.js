(function () {
  'use strict';

  // Tap/click to zoom any figure marked .zoomable-figure — mainly for reading
  // dense charts on small screens. No dependencies.

  document.addEventListener('DOMContentLoaded', function () {
    var figures = document.querySelectorAll('.zoomable-figure img');
    if (!figures.length) return;

    var overlay = document.createElement('div');
    overlay.className = 'lightbox-overlay';
    var overlayImg = document.createElement('img');
    overlay.appendChild(overlayImg);
    document.body.appendChild(overlay);

    function close() {
      overlay.classList.remove('open');
      overlayImg.src = '';
    }

    overlay.addEventListener('click', close);

    figures.forEach(function (img) {
      img.addEventListener('click', function () {
        overlayImg.src = img.currentSrc || img.src;
        overlay.classList.add('open');
      });
    });
  });
})();
