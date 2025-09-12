defmodule LedgerWeb.PageController do
  use Phoenix.Controller

  def index(conn, _params) do
    require Logger
    Logger.info("PageController index called")

    html(conn, """
    <!DOCTYPE html>
    <html lang="de">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Tideland Ledger Test Page</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.5;
            max-width: 800px;
            margin: 0 auto;
            padding: 2rem;
            color: #333;
          }
          .header {
            background-color: #3c5c76;
            color: white;
            padding: 1rem;
            margin-bottom: 2rem;
            border: 2px solid red;
          }
          .content {
            background-color: white;
            padding: 2rem;
            border: 1px solid #cccccc;
          }
          .footer {
            margin-top: 2rem;
            padding: 1rem;
            background-color: #f5f5f5;
            text-align: center;
            border-top: 1px solid #cccccc;
          }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>Tideland Ledger Test Page</h1>
        </div>
        <div class="content">
          <h2>Static Test Page</h2>
          <p>This is a static test page to verify that the basic HTTP serving is working.</p>
          <p>If you can see this page, the Phoenix controller is functioning correctly.</p>
          <p>The current time is: #{DateTime.utc_now() |> DateTime.to_string()}</p>
          <hr>
          <h3>Next Steps</h3>
          <p>Try visiting the LiveView path: <a href="/">/</a></p>
          <p>Or try the debug route: <a href="/debug">/debug</a></p>
          <p>Or try the static dashboard: <a href="/static-dashboard">/static-dashboard</a></p>
        </div>
        <div class="footer">
          <p>Tideland Ledger - Static Test Page</p>
        </div>
      </body>
    </html>
    """)
  end

  def debug(conn, _params) do
    require Logger
    Logger.info("PageController debug called")

    # Send a plain text response
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Debug route working at #{DateTime.utc_now()}")
  end

  def dashboard(conn, _params) do
    require Logger
    Logger.info("PageController dashboard called")

    html(conn, """
    <!DOCTYPE html>
    <html lang="de">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content="#{Phoenix.Controller.get_csrf_token()}" />
        <title>Tideland Ledger Dashboard</title>
        <link rel="stylesheet" href="/assets/app.css" />
        <script defer src="/assets/app.js"></script>
      </head>
      <body>
        <div class="container">
          <header class="main-header">
            <div class="brand">Tideland Ledger</div>
            <div class="user-controls">
              <span class="user-name">[Benutzer]</span>
              <a href="#" class="logout-link">[Abmelden]</a>
            </div>
          </header>
          <div class="main-container">
            <nav class="menu">
              <a href="/" class="menu-item active">Übersicht</a>
              <a href="/entries" class="menu-item">Buchungen</a>
              <a href="/accounts" class="menu-item">Konten</a>
              <a href="/templates" class="menu-item">Vorlagen</a>
              <a href="/reports" class="menu-item">Berichte</a>
              <a href="/users" class="menu-item">Benutzer</a>
            </nav>
            <main class="content">
              <div class="dashboard">
                <header class="header">
                  <h1>Übersicht</h1>
                </header>

                <div class="dashboard-grid">
                  <section class="card">
                    <div class="card-header">
                      <h2>Kontensalden</h2>
                      <div class="card-actions">
                        <button class="button secondary">Alle Konten anzeigen</button>
                      </div>
                    </div>
                    <div class="card-content">
                      <div class="account-balances">
                        <div class="account-balance">
                          <div class="account-name">Bank: Girokonto</div>
                          <div class="account-amount">12.500,00 €</div>
                        </div>
                        <div class="account-balance">
                          <div class="account-name">Kasse</div>
                          <div class="account-amount">250,00 €</div>
                        </div>
                        <div class="account-balance">
                          <div class="account-name">Forderungen</div>
                          <div class="account-amount">5.000,00 €</div>
                        </div>
                      </div>
                    </div>
                  </section>

                  <section class="card">
                    <div class="card-header">
                      <h2>Letzte Buchungen</h2>
                      <div class="card-actions">
                        <button class="button secondary">Alle Buchungen anzeigen</button>
                      </div>
                    </div>
                    <div class="card-content">
                      <div class="recent-entries">
                        <div class="recent-entry">
                          <div class="entry-date">15.01.23</div>
                          <div class="entry-description">Miete</div>
                          <div class="entry-amount">-1.500,00 €</div>
                        </div>
                        <div class="recent-entry">
                          <div class="entry-date">14.01.23</div>
                          <div class="entry-description">Material</div>
                          <div class="entry-amount">-125,50 €</div>
                        </div>
                        <div class="recent-entry">
                          <div class="entry-date">13.01.23</div>
                          <div class="entry-description">Zahlung</div>
                          <div class="entry-amount">2.000,00 €</div>
                        </div>
                      </div>
                    </div>
                  </section>
                </div>

                <section class="card">
                  <div class="card-header">
                    <h2>Schnellaktionen</h2>
                  </div>
                  <div class="card-content">
                    <div class="quick-actions">
                      <button class="button">Neue Buchung</button>
                      <button class="button">Vorlage anwenden</button>
                      <button class="button">Bericht erstellen</button>
                    </div>
                  </div>
                </section>
              </div>
            </main>
          </div>
          <footer class="main-footer">
            <div class="status-message">[Status: Bereit]</div>
            <div class="footer-controls">
              <span class="version">v0.1.0</span>
              <a href="#" class="help-link">[Hilfe]</a>
            </div>
          </footer>
        </div>
      </body>
    </html>
    """)
  end
end
