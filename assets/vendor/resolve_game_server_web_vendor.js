const fs = require("fs")
const path = require("path")

const candidateRoots = [
  path.join(__dirname, "../../apps/game_server_web/assets/vendor"),
  path.join(__dirname, "../../deps/game_server_web/assets/vendor"),
  path.join(__dirname, "../../deps/game_server_web/apps/game_server_web/assets/vendor")
]

module.exports = function resolveGameServerWebVendor(filename) {
  for (const root of candidateRoots) {
    const candidate = path.join(root, filename)

    if (fs.existsSync(candidate)) {
      return candidate
    }
  }

  throw new Error(
    `Could not locate ${filename} in game_server_web vendor assets. Tried: ${candidateRoots.join(", ")}`
  )
}
