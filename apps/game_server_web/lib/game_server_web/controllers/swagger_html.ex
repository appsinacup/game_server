defmodule GameServerWeb.SwaggerHTML do
  use GameServerWeb, :html

  def index(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Game Server API Documentation</title>
        <link
          rel="stylesheet"
          href="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.10.5/swagger-ui.css"
        />
        <style>
          body { background-color: white !important; color: black !important; margin: 0; }
          .swagger-ui { background-color: white !important; }
          .sdk-bar {
            background: #1e293b;
            color: #f8fafc;
            padding: 12px 24px;
            display: flex;
            align-items: center;
            gap: 16px;
            font-family: system-ui, -apple-system, sans-serif;
            font-size: 14px;
          }
          .sdk-bar span { font-weight: 600; }
          .sdk-bar a {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            padding: 6px 14px;
            border-radius: 6px;
            text-decoration: none;
            font-weight: 500;
            font-size: 13px;
            transition: background 0.15s;
          }
          .sdk-bar a.js-sdk { background: #f7df1e; color: #1e293b; }
          .sdk-bar a.js-sdk:hover { background: #e5cd00; }
          .sdk-bar a.godot-sdk { background: #478cbf; color: #fff; }
          .sdk-bar a.godot-sdk:hover { background: #3a7aab; }
          .sdk-bar a svg { width: 16px; height: 16px; }
        </style>
      </head>
      <body>
        <div class="sdk-bar">
          <span>SDKs:</span>
          <a href="https://www.npmjs.com/package/@ughuuu/game_server" target="_blank" rel="noopener" class="js-sdk">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M0 0v24h24V0H0zm6.672 20.4H3.6V6.6h3.072v13.8zm6.528 0H10.2V6.6h6.6v10.2h-3.6v3.6zm7.2 0h-3.072V6.6H20.4v13.8zM13.8 9.672v4.128h-3.6V9.672h3.6z"/></svg>
            JS SDK
          </a>
          <a href="https://godotengine.org/asset-library/asset/4510" target="_blank" rel="noopener" class="godot-sdk">
            <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/></svg>
            Godot SDK
          </a>
        </div>
        <div id="swagger-ui"></div>
        <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.10.5/swagger-ui-bundle.js">
        </script>
        <script src="https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.10.5/swagger-ui-standalone-preset.js">
        </script>
        <script>
          window.onload = function() {
            window.ui = SwaggerUIBundle({
              url: "/api/openapi",
              dom_id: '#swagger-ui',
              presets: [
                SwaggerUIBundle.presets.apis,
                SwaggerUIStandalonePreset
              ],
              layout: "StandaloneLayout",
              theme: "default"
            });
          };
        </script>
      </body>
    </html>
    """
  end
end
