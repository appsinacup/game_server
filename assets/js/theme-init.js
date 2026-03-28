// Theme initializer — runs synchronously before CSS to prevent FOUC.
// This file is a separate esbuild entry point loaded without `defer`.
(function () {
  var t = localStorage.getItem("phx:theme");
  var d =
    t ||
    (window.matchMedia("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light");
  document.documentElement.setAttribute("data-theme", d);
})();
