const fs = require("fs")
const path = require("path")
const plugin = require("tailwindcss/plugin")

const flagsDir = path.join(__dirname, "flag-icons/flags/4x3")
const flagCodes = [
  "bg",
  "br",
  "cn",
  "cz",
  "de",
  "dk",
  "es",
  "fi",
  "fr",
  "gb",
  "gr",
  "hu",
  "id",
  "it",
  "jp",
  "kr",
  "nl",
  "no",
  "pl",
  "pt",
  "ro",
  "ru",
  "sa",
  "se",
  "th",
  "tr",
  "tw",
  "ua",
  "vn",
  "xx"
]

function svgDataUrl(file) {
  const content = fs.readFileSync(file).toString().replace(/\r?\n|\r/g, "")
  return `url("data:image/svg+xml,${encodeURIComponent(content)}")`
}

module.exports = plugin(function ({ addComponents }) {
  if (!fs.existsSync(flagsDir)) {
    throw new Error(`Could not locate flag-icons SVGs at ${flagsDir}`)
  }

  const components = {
    ".fi": {
      "background-position": "50%",
      "background-repeat": "no-repeat",
      "background-size": "contain",
      display: "inline-block",
      "line-height": "1em",
      position: "relative",
      width: "1.333333em"
    },
    ".fi:before": {
      content: '"\\00a0"'
    },
    ".fis": {
      width: "1em"
    }
  }

  for (const code of flagCodes) {
    components[`.fi-${code}`] = {
      "background-image": svgDataUrl(path.join(flagsDir, `${code}.svg`))
    }
  }

  addComponents(components)
})
