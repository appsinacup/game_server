const defaultTheme = require('tailwindcss/defaultTheme')

/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    '../lib/**/*.{ex,heex,leex}',
    './**/*.{js,css,ts,jsx,tsx,heex}'
  ],
  theme: {
    extend: {
      fontFamily: {
        // Make Inter the default sans font for `font-sans` in the asset pipeline
        sans: ["Inter", ...defaultTheme.fontFamily.sans],
      },
      fontWeight: {
        medium: '450',
      },
    },
  },
  plugins: [],
}
