/**
 * Animates numbers from 0 up to a target when they scroll into view.
 *
 * Markup:
 *   <div data-count-up>
 *     <div data-count-to="100" data-count-suffix="+">0+</div>
 *   </div>
 *
 * The element's text content is the pre-animation value, so the numbers are
 * still meaningful without JS, with an ad blocker, or before the bundle loads.
 *
 * Fires once. A counter that replays on every scroll past reads as a glitch
 * rather than a flourish.
 */

const DURATION_MS = 1600

// Ease-out cubic: fast start, gentle settle. A linear count looks mechanical.
function easeOut(t) {
  return 1 - Math.pow(1 - t, 3)
}

function animate(el) {
  const target = Number(el.dataset.countTo)
  if (!Number.isFinite(target)) return

  const suffix = el.dataset.countSuffix || ""

  // Respect the OS setting rather than animating regardless — some people get
  // motion sick, and a counter is decorative.
  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches
  if (reduced) {
    el.textContent = `${target}${suffix}`
    return
  }

  const start = performance.now()

  function frame(now) {
    const progress = Math.min((now - start) / DURATION_MS, 1)
    const value = Math.round(target * easeOut(progress))
    el.textContent = `${value}${suffix}`
    if (progress < 1) requestAnimationFrame(frame)
  }

  requestAnimationFrame(frame)
}

export function init() {
  const groups = document.querySelectorAll("[data-count-up]")
  if (groups.length === 0) return

  const counters = (group) => group.querySelectorAll("[data-count-to]")

  // No IntersectionObserver (old browsers): show the final values rather than
  // leaving zeros on screen.
  if (!("IntersectionObserver" in window)) {
    groups.forEach((group) =>
      counters(group).forEach((el) => {
        el.textContent = `${el.dataset.countTo}${el.dataset.countSuffix || ""}`
      })
    )
    return
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return
        counters(entry.target).forEach(animate)
        // Unobserve immediately so a fast scroll cannot start a second run.
        observer.unobserve(entry.target)
      })
    },
    // Wait until a good part of the row is visible, so the animation is not
    // half over by the time it is actually on screen.
    { threshold: 0.4 }
  )

  groups.forEach((group) => observer.observe(group))
}
