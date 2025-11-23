const defaultTheme = require('tailwindcss/defaultTheme')

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './lib/**/*.{ex,heex,leex}',
    './assets/**/*.{js,css,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      fontFamily: {
        // Make Inter the default system sans font for `font-sans`
        sans: ["Inter", ...defaultTheme.fontFamily.sans],
      },
      // Tune the font-weight scale a bit for nicer visual balance with Inter
      fontWeight: {
        hairline: '100',
        thin: '200',
        light: '300',
        normal: '400',
        // a slightly heavier 'medium' that's softer than 500
        medium: '450',
        semibold: '600',
        bold: '700',
        extrabold: '800',
        black: '900',
      },
    },
  },
  plugins: [],
}
