defmodule GymStudioWeb.OfflineController do
  use GymStudioWeb, :controller

  def index(conn, _params) do
    conn
    |> put_layout(false)
    |> put_resp_content_type("text/html")
    |> send_resp(200, """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>React Gym — Offline</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          display: flex;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          margin: 0;
          background: #f5f5f5;
          color: #333;
          text-align: center;
        }
        .container { padding: 2rem; }
        h1 { color: #DC2626; font-size: 2rem; margin-bottom: 0.5rem; }
        p { color: #666; font-size: 1.1rem; line-height: 1.6; }
        .icon { font-size: 4rem; margin-bottom: 1rem; }
        .retry {
          display: inline-block;
          margin-top: 1.5rem;
          padding: 0.75rem 2rem;
          background: #DC2626;
          color: white;
          border: none;
          border-radius: 0.5rem;
          font-size: 1rem;
          cursor: pointer;
          text-decoration: none;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="icon">📡</div>
        <h1>You're Offline</h1>
        <p>It looks like you've lost your internet connection.<br/>Check your connection and try again.</p>
        <a href="/" class="retry" onclick="window.location.reload(); return false;">Try Again</a>
      </div>
    </body>
    </html>
    """)
  end
end
