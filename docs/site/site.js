(() => {
  const root = document.documentElement;
  root.classList.add("js");

  const hasIO = "IntersectionObserver" in window;

  /* Mobile menu */
  const toggle = document.querySelector(".nav-toggle");
  const menu = document.getElementById("menu");
  const setMenu = (open) => {
    if (!toggle || !menu) return;
    toggle.setAttribute("aria-expanded", String(open));
    toggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    menu.classList.toggle("is-open", open);
    document.body.classList.toggle("menu-open", open);
  };
  if (toggle && menu) {
    toggle.addEventListener("click", () => setMenu(toggle.getAttribute("aria-expanded") !== "true"));
    menu.querySelectorAll("a").forEach((a) => a.addEventListener("click", () => setMenu(false)));
    document.addEventListener("keydown", (e) => { if (e.key === "Escape") setMenu(false); });
    matchMedia("(min-width: 768px)").addEventListener("change", (e) => { if (e.matches) setMenu(false); });
  }

  /* Scroll reveals, once per element */
  const revealEls = document.querySelectorAll("[data-reveal]");
  if (hasIO) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-in");
        io.unobserve(entry.target);
      });
    }, { threshold: 0.12, rootMargin: "0px 0px -8% 0px" });
    revealEls.forEach((el) => io.observe(el));
  } else {
    revealEls.forEach((el) => el.classList.add("is-in"));
  }

  /* Tagline: words light up one at a time as they cross the trigger line */
  const tagline = document.querySelector("[data-tagline]");
  if (tagline && hasIO) {
    const text = tagline.textContent.trim().split(/\s+/);
    tagline.textContent = "";
    const words = text.map((word, i) => {
      const span = document.createElement("span");
      span.className = "w";
      span.textContent = word;
      tagline.append(span);
      if (i < text.length - 1) tagline.append(" ");
      return span;
    });
    const wordIO = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        const passed = entry.isIntersecting || entry.boundingClientRect.top < 0;
        entry.target.classList.toggle("is-on", passed);
      });
    }, { threshold: 0, rootMargin: "0px 0px -45% 0px" });
    words.forEach((w) => wordIO.observe(w));
  }

  /* Current section in the navigation */
  const links = [...document.querySelectorAll(".nav-links a[href^='#']")];
  if (hasIO && links.length) {
    const byId = new Map(links.map((a) => [a.getAttribute("href").slice(1), a]));
    const spy = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        links.forEach((a) => a.removeAttribute("aria-current"));
        const link = byId.get(entry.target.id);
        if (link) link.setAttribute("aria-current", "true");
      });
    }, { rootMargin: "-40% 0px -55% 0px" });
    byId.forEach((_, id) => { const s = document.getElementById(id); if (s) spy.observe(s); });
  }

  /* Copy the Homebrew command */
  document.querySelectorAll("[data-copy]").forEach((btn) => {
    const label = btn.querySelector("[data-copy-label]");
    const icon = btn.querySelector("i");
    const status = document.getElementById(btn.dataset.status || "");
    let timer;
    const flash = (ok) => {
      clearTimeout(timer);
      if (label) label.textContent = ok ? "Copied" : "Copy";
      if (icon) icon.className = ok ? "ph ph-check" : "ph ph-copy";
      if (status) status.textContent = ok
        ? "Command copied to the clipboard."
        : "Copy failed. Select the command and press Command C.";
      timer = setTimeout(() => {
        if (label) label.textContent = "Copy";
        if (icon) icon.className = "ph ph-copy";
        if (status) status.textContent = "";
      }, 2400);
    };
    btn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(btn.dataset.copy);
        flash(true);
      } catch (_) {
        flash(false);
      }
    });
  });
})();
