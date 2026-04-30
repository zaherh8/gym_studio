function initCarousel(el) {
  let currentIndex = 0
  const slides = el.querySelectorAll("[data-slide]")
  const dots = el.querySelectorAll("[data-dot]")
  const total = slides.length
  if (total === 0) return

  function goTo(index) {
    slides.forEach((slide, i) => {
      slide.style.opacity = i === index ? "1" : "0"
      slide.style.position = i === index ? "relative" : "absolute"
      slide.style.pointerEvents = i === index ? "auto" : "none"
    })
    dots.forEach((dot, i) => {
      dot.classList.toggle("bg-primary", i === index)
      dot.classList.toggle("bg-gray-300", i !== index)
    })
    currentIndex = index
  }

  let timer = setInterval(() => goTo((currentIndex + 1) % total), 5000)

  function resetTimer() {
    clearInterval(timer)
    timer = setInterval(() => goTo((currentIndex + 1) % total), 5000)
  }

  dots.forEach((dot, i) => {
    dot.addEventListener("click", () => {
      goTo(i)
      resetTimer()
    })
  })

  // Swipe support
  let startX = 0
  let startY = 0

  el.addEventListener("touchstart", (e) => {
    startX = e.touches[0].clientX
    startY = e.touches[0].clientY
  }, { passive: true })

  el.addEventListener("touchend", (e) => {
    const dx = e.changedTouches[0].clientX - startX
    const dy = e.changedTouches[0].clientY - startY
    if (Math.abs(dx) < 50 || Math.abs(dy) > Math.abs(dx)) return

    if (dx < 0) {
      goTo((currentIndex + 1) % total)
    } else {
      goTo((currentIndex - 1 + total) % total)
    }
    resetTimer()
  }, { passive: true })

  // Initialize first slide
  goTo(0)
}

// Auto-initialize on DOM ready
document.addEventListener("DOMContentLoaded", () => {
  const el = document.querySelector("[data-testimonial-carousel]")
  if (el) initCarousel(el)
})
