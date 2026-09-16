/**
 * Trainer carousel — dot sync for a CSS scroll-snap track.
 *
 * The swiping itself is native CSS (`snap-x snap-mandatory` + `overflow-x`),
 * so the carousel works before this bundle loads, with JS disabled, and with
 * proper iOS momentum. This module only:
 *
 *   1. highlights the dot matching the card currently in view
 *   2. makes the dots scroll the track when clicked
 *
 * If it never runs, the section degrades to a horizontally scrollable row
 * with a static first dot, which is still usable.
 */

function initCarousel(root) {
  const track = root.querySelector("[data-trainer-track]")
  const slides = Array.from(root.querySelectorAll("[data-trainer-slide]"))
  const dots = Array.from(root.querySelectorAll("[data-trainer-dot]"))
  if (!track || slides.length === 0) return

  let current = 0

  function setActive(index) {
    if (index === current) return
    current = index
    dots.forEach((dot, i) => {
      const isActive = i === index
      dot.classList.toggle("bg-primary", isActive)
      dot.classList.toggle("bg-gray-300", !isActive)
      dot.setAttribute("aria-selected", String(isActive))
    })
  }

  // IntersectionObserver against the track rather than a scroll listener:
  // no throttling to tune, and it stays correct during momentum scrolling
  // when scroll events fire irregularly.
  if ("IntersectionObserver" in window) {
    const observer = new IntersectionObserver(
      (entries) => {
        // Several cards are partly visible at once, so pick the most visible
        // rather than reacting to whichever entry happens to fire last.
        const best = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0]
        if (best) setActive(slides.indexOf(best.target))
      },
      { root: track, threshold: [0.5, 0.75, 1] }
    )
    slides.forEach((slide) => observer.observe(slide))
  }

  dots.forEach((dot, i) => {
    dot.addEventListener("click", () => {
      // Measure against the rendered boxes rather than offsetLeft: the slides'
      // offset parent is not the track, so offsetLeft overshoots badly once
      // several cards fit on screen. scrollIntoView is also wrong here — it
      // scrolls the page vertically to centre the section.
      const delta =
        slides[i].getBoundingClientRect().left - track.getBoundingClientRect().left
      track.scrollTo({ left: track.scrollLeft + delta, behavior: "smooth" })
      setActive(i)
    })
  })
}

export function init() {
  document.querySelectorAll("[data-trainer-carousel]").forEach(initCarousel)
}
