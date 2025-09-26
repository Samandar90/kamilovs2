document.addEventListener("DOMContentLoaded", () => {
  const animatedEls = document.querySelectorAll(".fade-in, .fade-left, .fade-right, .zoom-in");

  function onScroll() {
    animatedEls.forEach(el => {
      const rect = el.getBoundingClientRect();
      if (rect.top < window.innerHeight - 50) {
        el.classList.add("visible");
      }
    });
  }

  window.addEventListener("scroll", onScroll);
  onScroll(); // запуск при загрузке
});
