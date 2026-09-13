/*
 * All rights reserved. See LICENSE.md.
 * Copyright (c) 2025-2026 Keelson contributors (Fred Cooke)
 *
 * Native ES module, no bundler, no dependencies. Smooth scrolling and anchor
 * offset are CSS, so this owns only what CSS cannot express: the menu state,
 * which bay the reader is in, how far down the keel has filled, and the reveal
 * on first sight.
 */

const masthead = document.querySelector('.masthead');
const burger = document.querySelector('.burger');
const menu = document.querySelector('.nav-menu');
const links = Array.from(menu?.querySelectorAll('a') ?? []);
// Bays and the subsections inside them both get a station on the keel, in
// document order. Subsections have no menu item of their own, so they inherit
// their bay's: one item stays lit for a whole run of dots.
// The hero is represented by its title rather than by its bay: a station at the
// top of the bay sits level with the banner plate, lit before anything has been
// read. The first dot now belongs to the wordmark.
const waypoints = Array.from(
  document.querySelectorAll('main .hero-title, main .bay:not(.bay-hero), main .sub'),
);
const stations = new Map(
  Array.from(document.querySelectorAll('.keel b'))
    .map((node) => [node.dataset.station, node]),
);

// offsetTop is relative to the offset parent, so a subsection inside a bay
// reports its offset within that bay. Walk the chain for a real page position.
const pageTop = (el) => {
  let y = 0;
  for (let node = el; node; node = node.offsetParent) {
    y += node.offsetTop;
  }
  return y;
};

// A link names its bay either by its own hash or, when it points off site, by
// data-bay. The GitHub item is the latter: clicking it leaves, but it still
// lights up when you reach the section it stands for.
const navFor = new Map();
links.forEach((link) => {
  const id = link.dataset.bay || (link.hash ? link.hash.slice(1) : '');
  if (id) {
    navFor.set(id, link);
  }
});
waypoints.forEach((point) => {
  if (navFor.has(point.id)) {
    return;
  }
  const bay = point.closest('.bay');
  if (bay && navFor.has(bay.id)) {
    navFor.set(point.id, navFor.get(bay.id));
  }
});

// Gates every animation, so a script failure leaves the page fully visible
// rather than blank with everything stuck at opacity 0.
document.body.classList.add('ready');

/* --------------------------------------------------------------------------
 * Menu
 * ----------------------------------------------------------------------- */

const setMenu = (open) => {
  burger.setAttribute('aria-expanded', String(open));
  menu.classList.toggle('open', open);
};

const menuIsOpen = () => burger.getAttribute('aria-expanded') === 'true';

if (burger && menu) {
  burger.addEventListener('click', () => setMenu(!menuIsOpen()));

  // Picking a destination ends the menu's job. On desktop the menu is always
  // visible and .open is inert, so this is safe to run unconditionally.
  links.forEach((link) => link.addEventListener('click', () => setMenu(false)));

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && menuIsOpen()) {
      setMenu(false);
      burger.focus();
    }
  });
}

/* --------------------------------------------------------------------------
 * Position: nav highlight and keel stations
 * ----------------------------------------------------------------------- */

/*
 * Position is driven by scroll offset rather than by an IntersectionObserver.
 * A bay that contains subsections stays intersecting for the whole run of them
 * and, being topmost, would win every time: the subsection stations then all
 * lit at once when the bay finally scrolled clear. Comparing against each
 * waypoint's own top gives each one its turn, bays and subsections alike.
 */
const markCurrent = (index) => {
  const active = navFor.get(waypoints[index]?.id);
  links.forEach((link) => {
    if (link === active) {
      link.setAttribute('aria-current', 'true');
    } else {
      link.removeAttribute('aria-current');
    }
  });

  // Every station up to and including the current one stays lit, so the keel
  // reads as progress along the hull rather than a single moving dot.
  waypoints.forEach((point, i) => {
    stations.get(point.id)?.classList.toggle('lit', i <= index);
  });
};

if (waypoints.length > 0) {
  // Reveal on first sight, then stop watching. Nothing re-hides on scroll back.
  const reveal = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('seen');
        reveal.unobserve(entry.target);
      }
    });
  }, { rootMargin: '0px 0px -12% 0px', threshold: 0.05 });

  document.querySelectorAll('main .bay').forEach((bay) => reveal.observe(bay));
}

/* --------------------------------------------------------------------------
 * Keel fill
 * ----------------------------------------------------------------------- */

const run = document.querySelector('.keel-run');

if (run) {
  let queued = false;

  const scrollRange = () =>
    document.documentElement.scrollHeight - window.innerHeight;

  /*
   * Stations are evenly spaced along the rail, and the fill is driven by the
   * same even scale rather than by raw scroll distance. Positioning them by
   * real document offset was honest but looked wrong: a short bay and a long
   * one are equally one step of the journey, so bunching dots around the long
   * sections read as a rendering fault rather than as information.
   */
  let tops = [];

  const placeStations = () => {
    const last = waypoints.length - 1;
    waypoints.forEach((point, i) => {
      const node = stations.get(point.id);
      if (node) {
        node.style.top = `${last > 0 ? (i / last) * 100 : 0}%`;
      }
    });
    // Cached here rather than per frame: pageTop walks the offset chain, and
    // nothing moves between relayouts.
    const top = masthead?.offsetHeight ?? 0;
    tops = waypoints.map((point) => pageTop(point) - top);
  };

  const draw = () => {
    queued = false;
    const last = waypoints.length - 1;
    if (last < 1 || tops.length !== waypoints.length) {
      return;
    }

    const y = window.scrollY;

    // Which leg of the journey we are on, and how far along it. The same index
    // drives the lit stations and the nav, so the fill can never disagree with
    // the dot it is running towards.
    let i = 0;
    while (i + 1 <= last && tops[i + 1] <= y) {
      i += 1;
    }

    // Above the first waypoint nothing is lit: the banner has no station.
    markCurrent(y >= tops[0] ? i : -1);

    let frac = 0;
    if (i < last) {
      const span = tops[i + 1] - tops[i];
      frac = span > 0 ? (y - tops[i]) / span : 0;
    }

    const at = (i + Math.min(Math.max(frac, 0), 1)) / last;
    run.style.height = `${Math.min(Math.max(at, 0), 1) * 100}%`;
  };

  // Coalesced into a frame: scroll fires far more often than the page paints.
  const onScroll = () => {
    if (!queued) {
      queued = true;
      requestAnimationFrame(draw);
    }
  };

  const relayout = () => {
    placeStations();
    onScroll();
  };

  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', relayout, { passive: true });

  // An image that arrives late moves everything below it, and tops would be
  // measured against a layout that no longer exists. The log shots declare
  // their size so they reserve space, but the upstream diagrams cannot: the
  // build fetches them and their dimensions are not ours to pin.
  document.querySelectorAll('img').forEach((img) => {
    if (!img.complete) {
      img.addEventListener('load', relayout, { once: true });
    }
  });

  // Late webfonts and images reflow the document and move every offsetTop, so
  // the stations are placed again once everything has settled.
  window.addEventListener('load', relayout);
  if (document.fonts?.ready) {
    document.fonts.ready.then(relayout);
  }

  relayout();
}
