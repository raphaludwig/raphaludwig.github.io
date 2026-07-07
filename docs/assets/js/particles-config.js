(function () {
  'use strict';

  // Retuned from vista-library's particles-config.js:
  // - color follows the site's teal accent + current light/dark theme (was hard-coded brown)
  // - lighter particle count + fps on small screens (mobile perf)
  // - no hover-grab on touch devices (hover doesn't exist there)
  // - fully disabled when the user prefers reduced motion

  function isDark() {
    var html = document.documentElement;
    return html.getAttribute('data-bs-theme') === 'dark' || html.classList.contains('quarto-dark');
  }

  function accentColor() {
    return isDark() ? '#2dd4bf' : '#0f766e';
  }

  function isTouch() {
    return window.matchMedia('(hover: none)').matches;
  }

  document.addEventListener('DOMContentLoaded', function () {
    var target = document.getElementById('particles-bg');
    if (!target) return;

    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

    var small = window.matchMedia('(max-width: 640px)').matches;
    var accent = accentColor();

    tsParticles.load('particles-bg', {
      background: { color: { value: 'transparent' } },
      fpsLimit: small ? 30 : 60,
      particles: {
        number: { value: small ? 40 : 90, density: { enable: true, area: 800 } },
        color: { value: accent },
        opacity: { value: 0.45, random: { enable: true, minimumValue: 0.2 } },
        size: { value: { min: 1.2, max: 2.6 } },
        links: { enable: true, distance: 140, color: accent, opacity: 0.25, width: 1 },
        move: {
          enable: true,
          speed: 0.6,
          direction: 'none',
          random: true,
          straight: false,
          outModes: { default: 'bounce' }
        }
      },
      interactivity: {
        detectsOn: 'window',
        events: {
          onHover: { enable: !isTouch(), mode: 'grab' },
          resize: true
        },
        modes: { grab: { distance: 130, links: { opacity: 0.5 } } }
      },
      detectRetina: true
    }).then(function (container) {
      // Keep particle color in sync when the user toggles light/dark.
      var observer = new MutationObserver(function () {
        var c = accentColor();
        container.options.particles.color.value = c;
        container.options.particles.links.color.value = c;
        container.refresh();
      });
      observer.observe(document.documentElement, { attributes: true, attributeFilter: ['data-bs-theme', 'class'] });
    });
  });
})();
