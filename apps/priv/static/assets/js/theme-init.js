(() => {
  // js/theme-init.js
  (function() {
    var t = localStorage.getItem("phx:theme");
    var d = t || (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
    var themeColorMeta = document.querySelector('meta[name="theme-color"]');
    if (themeColorMeta) {
      var lightColor = themeColorMeta.dataset.lightColor || themeColorMeta.content;
      var darkColor = themeColorMeta.dataset.darkColor || lightColor;
      themeColorMeta.setAttribute("content", d === "dark" ? darkColor : lightColor);
    }
    var colorSchemeMeta = document.querySelector('meta[name="color-scheme"]');
    if (colorSchemeMeta) {
      colorSchemeMeta.setAttribute("content", d);
    }
    document.documentElement.setAttribute("data-theme", d);
    document.cookie = "phx_theme=" + d + "; path=/; max-age=31536000; SameSite=Lax";
  })();
})();
