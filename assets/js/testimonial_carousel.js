function initCarousel(el) {
  let currentIndex = 0
  const slides = el.querySelectorAll("[data-slide]")
  const dots = el.querySelectorAll("[data-dot]")
  const total = slides.length
  if (total === 0) return

  function goTo(index) {
    slides.forEach((slide, i) => {
      const isActive = i === index
      slide.classList.toggle("opacity-100", isActive)
      slide.classList.toggle("relative", isActive)
      slide.classList.toggle("opacity-0", !isActive)
      slide.classList.toggle("absolute", !isActive)
      slide.classList.toggle("pointer-events-none", !isActive)
    })
    dots.forEach((dot, i) => {
      const isActive = i === index
      dot.classList.toggle("bg-primary", isActive)
      dot.classList.toggle("bg-gray-300", !isActive)
      dot.setAttribute("aria-selected", isActive)
    })
    currentIndex = index
    const liveRegion = el.querySelector("[aria-live]")
    if (liveRegion) {
      liveRegion.setAttribute("aria-label", `Slide ${index + 1} of ${total}`)
    }
  }

  let timer = null
  let userPaused = false

  function startTimer() {
    if (timer) return
    timer = setInterval(() => goTo((currentIndex + 1) % total), 5000)
  }

  function stopTimer() {
    clearInterval(timer)
    timer = null
  }

  function pauseForInteraction() {
    // Once the user interacts (click, swipe, keyboard), auto-rotation is
    // permanently disabled to respect their preference.
    userPaused = true
    stopTimer()
  }

  // Intersection Observer: auto-rotate only when visible
  const visibilityObserver = new IntersectionObserver(
    (entries) => {
      const entry = entries[0]
      if (entry.isIntersecting && !userPaused) {
        startTimer()
      } else {
        stopTimer()
      }
    },
    { threshold: 0.3 }
  )
  visibilityObserver.observe(el)

  dots.forEach((dot, i) => {
    dot.addEventListener("click", () => {
      goTo(i)
      pauseForInteraction()
    })
  })

  // Keyboard navigation
  function handleKeydown(e) {
    if (e.key === "ArrowLeft") {
      goTo((currentIndex - 1 + total) % total)
      pauseForInteraction()
    } else if (e.key === "ArrowRight") {
      goTo((currentIndex + 1) % total)
      pauseForInteraction()
    }
  }
  el.addEventListener("keydown", handleKeydown)

  // Swipe support
  let startX = 0
  let startY = 0

  function handleTouchstart(e) {
    startX = e.touches[0].clientX
    startY = e.touches[0].clientY
  }

  function handleTouchend(e) {
    const dx = e.changedTouches[0].clientX - startX
    const dy = e.changedTouches[0].clientY - startY
    if (Math.abs(dx) < 50 || Math.abs(dy) > Math.abs(dx)) return

    if (dx < 0) {
      goTo((currentIndex + 1) % total)
    } else {
      goTo((currentIndex - 1 + total) % total)
    }
    pauseForInteraction()
  }

  el.addEventListener("touchstart", handleTouchstart, { passive: true })
  el.addEventListener("touchend", handleTouchend, { passive: true })

  // Cleanup: observe DOM removal to clear interval and listeners
  const mutationObserver = new MutationObserver(() => {
    if (!document.body.contains(el)) {
      stopTimer()
      visibilityObserver.disconnect()
      el.removeEventListener("keydown", handleKeydown)
      el.removeEventListener("touchstart", handleTouchstart)
      el.removeEventListener("touchend", handleTouchend)
      mutationObserver.disconnect()
    }
  })
  mutationObserver.observe(document.body, { childList: true, subtree: true })

  // Initialize first slide
  goTo(0)
}

export function init() {
  const el = document.querySelector("[data-testimonial-carousel]")
  if (el) initCarousel(el)
}
