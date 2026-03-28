// Theme switcher & card collapse/expand — imported by app.js
// Manages data-theme attribute, localStorage persistence, and system preference listening.

const getSystemTheme = () =>
  window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";

const setTheme = (theme) => {
  const actualTheme = theme === "system" ? getSystemTheme() : theme;
  if (theme !== "system") {
    localStorage.setItem("phx:theme", theme);
  } else {
    localStorage.removeItem("phx:theme");
  }
  document.documentElement.setAttribute("data-theme", actualTheme);
};

// Set initial theme — default to system preference if no stored preference
const storedTheme = localStorage.getItem("phx:theme");
setTheme(storedTheme || "system");

// Listen for system theme changes (only if no explicit preference is set)
window
  .matchMedia("(prefers-color-scheme: dark)")
  .addEventListener("change", () => {
    if (!localStorage.getItem("phx:theme")) {
      setTheme("system");
    }
  });

window.addEventListener("phx:set-theme", (e) => {
  // Find the button with data-phx-theme attribute (could be the target or its parent)
  const button = e.target.closest("[data-phx-theme]");
  if (button) {
    setTheme(button.dataset.phxTheme);
  }
});

// ---------------------------------------------------------------------------
// Card collapse/expand state handling (UI-only, always collapsed by default)
// ---------------------------------------------------------------------------

const setCardCollapsed = (cardEl, collapsed) => {
  if (collapsed) {
    cardEl.classList.add("collapsed");
    const key = cardEl.dataset.cardKey;
    const btn = cardEl.querySelector(
      `[data-action="toggle-card"][data-card-key="${key}"]`
    );
    if (btn) btn.setAttribute("aria-expanded", "false");
  } else {
    cardEl.classList.remove("collapsed");
    const key = cardEl.dataset.cardKey;
    const btn = cardEl.querySelector(
      `[data-action="toggle-card"][data-card-key="${key}"]`
    );
    if (btn) btn.setAttribute("aria-expanded", "true");
  }
};

// Initialize collapsed state on DOMContentLoaded so attributes are set consistently
document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll("[data-card-key]").forEach((card) => {
    const collapsed = card.classList.contains("collapsed");
    setCardCollapsed(card, collapsed);
  });
});

// Toggle handler
document.addEventListener("click", (e) => {
  const btn = e.target.closest("[data-action='toggle-card']");
  if (!btn) return;
  const key = btn.dataset.cardKey;
  const card = document.querySelector(`[data-card-key="${key}"]`);
  if (!card) return;
  const collapsed = card.classList.toggle("collapsed");
  setCardCollapsed(card, collapsed);
});

const handleAnchor = () => {
  const hash = window.location.hash;
  if (!hash) return;
  const key = hash.replace("#", "");
  const card = document.querySelector(`.card[data-card-key="${key}"]`);
  if (card) {
    setCardCollapsed(card, false);
    // Scroll with an offset to ensure the title is visible
    const yOffset = -80;
    const y = card.getBoundingClientRect().top + window.pageYOffset + yOffset;
    window.scrollTo({ top: y, behavior: "smooth" });
  }
};

window.addEventListener("load", handleAnchor);
window.addEventListener("hashchange", handleAnchor);
window.addEventListener("phx:page-loading-stop", handleAnchor);
