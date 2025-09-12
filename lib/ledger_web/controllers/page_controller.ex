defmodule LedgerWeb.PageController do
  use Phoenix.Controller
  require Logger

  # For format helpers
  import LedgerWeb.LiveHelpers, only: [format_amount: 1, format_date: 1]

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

  def troubleshoot(conn, _params) do
    require Logger
    Logger.info("PageController troubleshoot called")

    # Check Phoenix and LiveView version
    phoenix_version = Phoenix.VERSION
    liveview_version = Phoenix.LiveView.VERSION

    html(conn, """
    <!DOCTYPE html>
    <html lang="de">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content="#{Phoenix.Controller.get_csrf_token()}" />
        <title>LiveView Troubleshooting</title>
        <link rel="stylesheet" href="/assets/app.css" />
        <script defer src="/assets/app.js"></script>
      </head>
      <body>
        <div style="padding: 20px; background-color: #f5f5f5; margin: 20px; border-radius: 5px; border: 2px solid #3c5c76;">
          <h1 style="color: #3c5c76;">LiveView Troubleshooting</h1>

          <!-- Add inline LiveView initialization script -->
          <script>
            // Initialize LiveView immediately
            document.addEventListener("DOMContentLoaded", function() {
              console.log("Inline initialization starting");

              // Try to create LiveSocket if Phoenix is available
              if (window.Phoenix && window.Phoenix.LiveView) {
                console.log("Phoenix and LiveView available, initializing socket");

                try {
                  // Get CSRF token
                  const token = document.querySelector('meta[name="csrf-token"]').getAttribute("content");

                  // Create LiveSocket
                  window.liveSocket = new window.Phoenix.LiveView.LiveSocket(
                    "/live",
                    window.Phoenix.Socket,
                    { params: { _csrf_token: token } }
                  );

                  // Connect
                  window.liveSocket.connect();
                  console.log("LiveSocket initialized in troubleshooting page");
                } catch (e) {
                  console.error("Error initializing LiveView:", e);
                }
              } else {
                console.error("Phoenix or LiveView not available in window");
              }
            });
          </script>

          <div style="margin: 20px 0; padding: 15px; background-color: white; border: 1px solid #ccc;">
            <h2>System Information</h2>
            <ul>
              <li>Phoenix Version: #{phoenix_version}</li>
              <li>LiveView Version: #{liveview_version}</li>
              <li>Server Time: #{DateTime.utc_now()}</li>
              <li>CSRF Token Present: Yes</li>
            </ul>
          </div>

          <div style="margin: 20px 0; padding: 15px; background-color: white; border: 1px solid #ccc;">
            <h2>Static Asset Check</h2>
            <p>CSS File: <span id="css-status">Checking...</span></p>
            <p>JS File: <span id="js-status">Checking...</span></p>
            <script>
              document.addEventListener("DOMContentLoaded", function() {
                // Check if CSS loaded correctly
                const styles = document.styleSheets;
                let cssLoaded = false;
                for (let i = 0; i < styles.length; i++) {
                  try {
                    if (styles[i].href && styles[i].href.includes('/assets/app.css')) {
                      cssLoaded = true;
                      break;
                    }
                  } catch (e) {}
                }
                document.getElementById("css-status").textContent = cssLoaded ? "Loaded ✓" : "Failed to load ✗";
                document.getElementById("css-status").style.color = cssLoaded ? "green" : "red";

                // Check if JS loaded correctly
                const jsLoaded = (typeof window.formatDate === "function");
                document.getElementById("js-status").textContent = jsLoaded ? "Loaded ✓" : "Failed to load ✗";
                document.getElementById("js-status").style.color = jsLoaded ? "green" : "red";

                // Add detailed Phoenix and LiveView diagnostics
                setTimeout(function() {
                  const diagDiv = document.createElement('div');
                  diagDiv.style.marginTop = '15px';
                  diagDiv.style.borderTop = '1px dashed #ccc';
                  diagDiv.style.paddingTop = '10px';

                  const items = [
                    {name: "Phoenix available", value: typeof window.Phoenix !== "undefined"},
                    {name: "Phoenix.Socket available", value: typeof window.Phoenix?.Socket !== "undefined"},
                    {name: "Phoenix.LiveView available", value: typeof window.Phoenix?.LiveView !== "undefined"},
                    {name: "Phoenix.LiveView.LiveSocket available", value: typeof window.Phoenix?.LiveView?.LiveSocket !== "undefined"},
                    {name: "window.liveSocket exists", value: typeof window.liveSocket !== "undefined"},
                  ];

                  let html = '<h4>Detailed JavaScript Diagnostics:</h4><ul>';
                  items.forEach(item => {
                    html += `<li>${item.name}: <span style="color:${item.value ? 'green' : 'red'}">${item.value ? '✓' : '✗'}</span></li>`;
                  });
                  html += '</ul>';

                  if (typeof window.Phoenix !== "undefined") {
                    html += `<p>Phoenix version: <code>${window.Phoenix.VERSION || 'unknown'}</code></p>`;
                  }

                  diagDiv.innerHTML = html;
                  document.getElementById("js-status").parentNode.appendChild(diagDiv);
                }, 500);
              });
            </script>
          </div>

          <div style="margin: 20px 0; padding: 15px; background-color: white; border: 1px solid #ccc;">
            <h2>LiveView Connection Check</h2>
            <p>LiveSocket Global: <span id="livesocket-status">Checking...</span></p>
            <p>Socket Connection: <span id="connection-status">Checking...</span></p>
            <script>
              document.addEventListener("DOMContentLoaded", function() {
                setTimeout(function() {
                  // Check if LiveSocket exists
                  const lsExists = (typeof window.liveSocket !== "undefined");
                  document.getElementById("livesocket-status").textContent = lsExists ? "Available ✓" : "Not Found ✗";
                  document.getElementById("livesocket-status").style.color = lsExists ? "green" : "red";

                  // Check socket connection
                  let connectionStatus = "Not available";
                  let color = "red";

                  if (lsExists) {
                    try {
                      if (window.liveSocket.isConnected()) {
                        connectionStatus = "Connected ✓";
                        color = "green";
                      } else {
                        connectionStatus = "Disconnected ✗";
                      }
                    } catch (e) {
                      connectionStatus = "Error: " + e.message;
                    }
                  }

                  document.getElementById("connection-status").textContent = connectionStatus;
                  document.getElementById("connection-status").style.color = color;

                  // Add additional connection diagnostics
                  const diagDiv = document.createElement('div');
                  diagDiv.style.marginTop = '15px';
                  diagDiv.style.borderTop = '1px dashed #ccc';
                  diagDiv.style.paddingTop = '10px';

                  let html = '<h4>WebSocket Diagnostics:</h4>';

                  // Check WebSocket support
                  html += `<p>Browser WebSocket support: <span style="color:${typeof WebSocket !== 'undefined' ? 'green' : 'red'}">${typeof WebSocket !== 'undefined' ? '✓' : '✗'}</span></p>`;

                  // Attempt direct WebSocket connection test
                  html += `<p>Test connection: <button id="test-ws-btn" class="button">Test Direct WebSocket</button> <span id="ws-test-result"></span></p>`;

                  // Add CSRF token info
                  const csrfEl = document.querySelector('meta[name="csrf-token"]');
                  html += `<p>CSRF Token: ${csrfEl ? csrfEl.getAttribute('content').substring(0, 10) + '...' : 'Not found'}</p>`;

                  // Add LiveView elements info
                  const liveElements = document.querySelectorAll('[data-phx-view]');
                  html += `<p>LiveView elements on page: <span id="live-elements-count">${liveElements.length}</span></p>`;
                  if (liveElements.length > 0) {
                    html += '<ul>';
                    Array.from(liveElements).forEach((el, i) => {
                      html += `<li>Element ${i+1}: View=${el.getAttribute('data-phx-view')}, ID=${el.id}</li>`;
                    });
                    html += '</ul>';
                  }

                  diagDiv.innerHTML = html;
                  document.getElementById("connection-status").parentNode.appendChild(diagDiv);

                  // Add test WebSocket functionality
                  document.getElementById('test-ws-btn').addEventListener('click', function() {
                    const resultEl = document.getElementById('ws-test-result');
                    resultEl.textContent = 'Testing...';
                    resultEl.style.color = 'blue';

                    try {
                      const ws = new WebSocket(`ws://${window.location.host}/live/websocket?vsn=2.0.0`);

                      ws.onopen = function() {
                        resultEl.textContent = 'Connection successful! ✓';
                        resultEl.style.color = 'green';
                        setTimeout(() => ws.close(), 2000);
                      };

                      ws.onerror = function() {
                        resultEl.textContent = 'Connection failed! ✗';
                        resultEl.style.color = 'red';
                      };

                      ws.onclose = function() {
                        console.log('WebSocket test connection closed');
                      };
                    } catch (e) {
                      resultEl.textContent = `Error: ${e.message}`;
                      resultEl.style.color = 'red';
                    }
                  });
                }, 1000);
              });
            </script>
          </div>

          <div style="margin: 20px 0; padding: 15px; background-color: white; border: 1px solid #ccc;">
            <h2>Test LiveView Features</h2>
            <p>These buttons simulate LiveView operations but don't actually use LiveView:</p>
            <div style="margin-top: 15px;">
              <button id="counter-btn" style="padding: 5px 10px; background-color: #3c5c76; color: white; border: none; margin-right: 10px;">
                Increment Counter: <span id="counter">0</span>
              </button>
              <button id="time-btn" style="padding: 5px 10px; background-color: #3c5c76; color: white; border: none;">
                Update Time
              </button>
              <div id="time-display" style="margin-top: 10px;"></div>
            </div>
            <script>
              document.addEventListener("DOMContentLoaded", function() {
                // Simple counter
                let count = 0;
                document.getElementById("counter-btn").addEventListener("click", function() {
                  count++;
                  document.getElementById("counter").textContent = count;
                });

                // Time display
                function updateTime() {
                  const now = new Date();
                  document.getElementById("time-display").textContent = now.toISOString();
                }
                updateTime();
                document.getElementById("time-btn").addEventListener("click", updateTime);
              });
            </script>
          </div>

          <div style="margin: 20px 0; padding: 15px; background-color: white; border: 1px solid #ccc;">
            <h2>Test Pages</h2>
            <p>Try these test pages to isolate the issue:</p>
            <ul>
              <li><a href="/static" style="color: #3c5c76;">Static Test Page</a> - Basic controller rendering</li>
              <li><a href="/static-dashboard" style="color: #3c5c76;">Static Dashboard</a> - Static version of the dashboard</li>
              <li><a href="/test" style="color: #3c5c76;">Test LiveView</a> - Simple LiveView test</li>
              <li><a href="/" style="color: #3c5c76;">Dashboard LiveView</a> - Main dashboard LiveView</li>
            </ul>

            <div style="margin-top: 15px; padding: 10px; background-color: #f8f8f8; border: 1px dashed #ccc;">
              <h3>LiveView Monitor</h3>
              <p>A floating monitor has been added to the bottom-right corner of the page. It will show LiveView connection status in real-time.</p>
              <p>You can also use these diagnostic functions in your browser console:</p>
              <ul>
                <li><code>window.diagnoseLiveView()</code> - Run diagnostics</li>
                <li><code>window.reconnectLiveView()</code> - Force reconnection</li>
              </ul>
            </div>
          </div>

          <div style="margin: 20px 0; padding: 15px; background-color: white; border: 1px solid #ccc;">
            <h2>Manual Fix Actions</h2>
            <p>These buttons attempt to fix common LiveView issues:</p>

            <button id="fix-init-btn" style="margin: 5px; padding: 8px 15px; background-color: #3c5c76; color: white; border: none; cursor: pointer;">
              Initialize LiveSocket Manually
            </button>

            <button id="fix-reload-btn" style="margin: 5px; padding: 8px 15px; background-color: #3c5c76; color: white; border: none; cursor: pointer;">
              Hard Reload Page
            </button>

            <div id="fix-result" style="margin-top: 10px; padding: 8px; border: 1px solid #ddd;"></div>

            <script>
              document.getElementById('fix-init-btn').addEventListener('click', function() {
                const resultEl = document.getElementById('fix-result');
                resultEl.innerHTML = 'Attempting to manually initialize LiveSocket...';

                try {
                  // Check if Phoenix is available
                  if (typeof window.Phoenix === 'undefined' || typeof window.Phoenix.LiveView === 'undefined') {
                    resultEl.innerHTML = 'Error: Phoenix or LiveView not available in window scope.';
                    return;
                  }

                  // Get CSRF token
                  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
                  if (!csrfToken) {
                    resultEl.innerHTML = 'Error: CSRF token not found!';
                    return;
                  }

                  // Create new LiveSocket
                  window.liveSocket = new window.Phoenix.LiveView.LiveSocket('/live', window.Phoenix.Socket, {
                    params: { _csrf_token: csrfToken }
                  });

                  // Connect
                  window.liveSocket.connect();

                  // Check if connected after a short delay
                  setTimeout(() => {
                    if (window.liveSocket.isConnected()) {
                      resultEl.innerHTML = '<span style="color:green">Success! LiveSocket connected. Try reloading the LiveView page now.</span>';
                    } else {
                      resultEl.innerHTML = '<span style="color:red">Failed to connect. Socket initialized but connection failed.</span>';
                    }
                  }, 1000);
                } catch (e) {
                  resultEl.innerHTML = `<span style="color:red">Error initializing LiveSocket: ${e.message}</span>`;
                }
              });

              document.getElementById('fix-reload-btn').addEventListener('click', function() {
                window.location.reload(true);
              });
            </script>
          </div>

          <div style="margin-top: 20px; font-size: 0.8em; color: #666; text-align: center;">
            <p>Troubleshooting page generated at: #{DateTime.utc_now()}</p>
          </div>
        </div>
      </body>
    </html>
    """)
  end

  def test_static(conn, _params) do
    require Logger
    Logger.info("PageController test_static called")

    html(conn, """
    <!DOCTYPE html>
    <html lang="de">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content="#{Phoenix.Controller.get_csrf_token()}" />
        <title>LiveView Test Static Comparison</title>
        <link rel="stylesheet" href="/assets/app.css" />
        <script defer src="/assets/app.js"></script>
      </head>
      <body>
        <div style="padding: 20px; background-color: #f5f5f5; border: 1px solid #ddd; margin: 20px; border-radius: 5px;">
          <h1 style="color: #333;">Static Test Page (For Comparison)</h1>

          <p>This is a static HTML version for comparison with the LiveView test.</p>

          <div style="margin: 20px 0; padding: 10px; background-color: white; border: 1px solid #ccc;">
            <p>Counter: <span style="font-weight: bold; font-size: 1.5em;">0</span></p>
            <button
              style="padding: 5px 10px; background-color: #3c5c76; color: white; border: none; cursor: pointer;"
              disabled
            >
              Increment Counter (Disabled - Static Version)
            </button>
          </div>

          <div style="margin: 20px 0; padding: 10px; background-color: white; border: 1px solid #ccc;">
            <p>Current time: <span style="font-weight: bold;">#{Time.utc_now()}</span></p>
            <button
              style="padding: 5px 10px; background-color: #3c5c76; color: white; border: none; cursor: pointer;"
              disabled
            >
              Refresh Time (Disabled - Static Version)
            </button>
          </div>

          <p style="margin-top: 20px;">
            <a href="/test" style="color: #3c5c76;">Try LiveView Version</a> |
            <a href="/" style="color: #3c5c76;">Back to Dashboard</a>
          </p>

          <div style="margin-top: 20px; font-size: 0.8em; color: #666;">
            <p>Debug Info:</p>
            <ul>
              <li>Page Type: Static HTML (No LiveView)</li>
              <li>Rendered at: #{DateTime.utc_now()}</li>
            </ul>
          </div>
        </div>
      </body>
    </html>
    """)
  end

  def static_dashboard_fallback(conn, _params) do
    require Logger
    Logger.info("PageController static_dashboard_fallback called")

    # Generate sample data similar to what DashboardLive would use
    account_balances = [
      %{id: "1", name: "Bank: Girokonto", balance: Decimal.new("12500.00")},
      %{id: "2", name: "Kasse", balance: Decimal.new("250.00")},
      %{id: "3", name: "Forderungen", balance: Decimal.new("5000.00")},
      %{id: "4", name: "Verbindlichkeiten", balance: Decimal.new("-3200.00")}
    ]

    recent_entries = [
      %{id: "1", date: ~D[2023-01-15], description: "Miete", amount: Decimal.new("-1500.00")},
      %{id: "2", date: ~D[2023-01-14], description: "Material", amount: Decimal.new("-125.50")},
      %{id: "3", date: ~D[2023-01-13], description: "Zahlung", amount: Decimal.new("2000.00")},
      %{id: "4", date: ~D[2023-01-10], description: "Bürobedarf", amount: Decimal.new("-89.75")},
      %{id: "5", date: ~D[2023-01-05], description: "Kundenrechnung", amount: Decimal.new("3500.00")}
    ]

    # Render template with the data
    render(conn, :dashboard_static,
      page_title: "Übersicht",
      current_path: "/",
      account_balances: account_balances,
      recent_entries: recent_entries
    )
  end

  # Keep the old HTML rendering method for reference
  def static_dashboard_fallback_html(conn, _params) do
    html(conn, """
    <!DOCTYPE html>
    <html lang="de">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content="#{Phoenix.Controller.get_csrf_token()}" />
        <title>Übersicht - Tideland Ledger</title>
        <link rel="stylesheet" href="/assets/app.css" />
        <style>
          /* Additional styles for static fallback */
          .dashboard-notice {
            background-color: #fff3cd;
            border: 1px solid #ffeeba;
            color: #856404;
            padding: 15px;
            margin-bottom: 20px;
            border-radius: 4px;
          }
          .card { margin-bottom: 20px; }
          .card-header {
            padding: 10px 15px;
            background-color: #3c5c76;
            color: white;
            display: flex;
            justify-content: space-between;
            align-items: center;
          }
          .card-content { padding: 15px; }
          .account-balance, .recent-entry {
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #eee;
          }
        </style>
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

                <div class="dashboard-notice">
                  <h3 style="margin-top:0">Statische Ansicht</h3>
                  <p>Dies ist eine vereinfachte statische Version des Dashboards. Einige interaktive Funktionen sind möglicherweise eingeschränkt.</p>
                </div>

                <div class="dashboard-grid">
                  <section class="card">
                    <div class="card-header">
                      <h2>Kontensalden</h2>
                      <div class="card-actions">
                        <a href="/entries" class="button secondary">Alle Konten anzeigen</a>
                      </div>
                    </div>
                    <div class="card-content">
                      <div class="account-balances">
                        <%= if Enum.empty?(account_balances) do %>
                          <p>Keine Konten vorhanden.</p>
                        <% else %>
                          <%= for account <- account_balances do %>
                            <div class="account-balance">
                              <div class="account-name"><%= account.name %></div>
                              <div class="account-amount"><%= format_amount(account.balance) %></div>
                            </div>
                          <% end %>
                        <% end %>
                      </div>
                    </div>
                  </section>

                  <section class="card">
                    <div class="card-header">
                      <h2>Letzte Buchungen</h2>
                      <div class="card-actions">
                        <a href="/entries" class="button secondary">Alle Buchungen anzeigen</a>
                      </div>
                    </div>
                    <div class="card-content">
                      <div class="recent-entries">
                        <%= if Enum.empty?(recent_entries) do %>
                          <p>Keine Buchungen vorhanden.</p>
                        <% else %>
                          <%= for entry <- recent_entries do %>
                            <div class="recent-entry">
                              <div class="entry-date"><%= format_date(entry.date) %></div>
                              <div class="entry-description"><%= entry.description %></div>
                              <div class="entry-amount"><%= format_amount(entry.amount) %></div>
                            </div>
                          <% end %>
                        <% end %>
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
                      <a href="/entries/new" class="button">Neue Buchung</a>
                      <a href="/entries" class="button">Vorlage anwenden</a>
                      <a href="/entries" class="button">Bericht erstellen</a>
                    </div>
                  </div>
                </section>
              </div>
            </main>
          </div>
          <footer class="main-footer">
            <div class="status-message">[Status: Statische Ansicht]</div>
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

  # Import formatting helpers for use in the template
  import LedgerWeb.LiveHelpers, only: [format_amount: 1, format_date: 1]

  def test_html(conn, _params) do
    require Logger
    Logger.info("PageController test_html called")

    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta name="csrf-token" content="#{Phoenix.Controller.get_csrf_token()}">
        <title>LiveView Test Page</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                line-height: 1.5;
                max-width: 800px;
                margin: 0 auto;
                padding: 2rem;
                color: #333;
            }
            .success { color: green; }
            .error { color: red; }
            .button {
                padding: 8px 16px;
                background: #3c5c76;
                color: white;
                border: none;
                border-radius: 4px;
                cursor: pointer;
            }
            pre {
                background: #f5f5f5;
                padding: 10px;
                overflow: auto;
                font-size: 14px;
            }
        </style>
    </head>
    <body>
        <h1>LiveView JavaScript Test</h1>

        <div id="test-controls">
            <h2>Step 1: Load Scripts</h2>
            <button id="load-phoenix" class="button">Load Phoenix</button>
            <button id="load-liveview" class="button">Load LiveView</button>

            <h2>Step 2: Initialize LiveView</h2>
            <button id="init-liveview" class="button">Initialize LiveView</button>

            <h2>Step 3: Test Connection</h2>
            <button id="test-connection" class="button">Test Connection</button>
        </div>

        <div id="results" style="margin-top: 20px;">
            <h2>Results</h2>
            <div id="phoenix-status">Phoenix: <span>Not loaded</span></div>
            <div id="liveview-status">LiveView: <span>Not loaded</span></div>
            <div id="socket-status">LiveSocket: <span>Not initialized</span></div>
            <div id="connection-status">Connection: <span>Not connected</span></div>
        </div>

        <div id="console-output">
            <h2>Console Output</h2>
            <pre id="console"></pre>
        </div>

        <script>
            // Console log override for display
            var originalConsoleLog = console.log;
            var originalConsoleError = console.error;
            var consoleOutput = document.getElementById('console');

            console.log = function() {
                var args = Array.prototype.slice.call(arguments);
                originalConsoleLog.apply(console, args);

                consoleOutput.innerHTML += '> ' + args.map(function(arg) {
                    return typeof arg === 'object' ? JSON.stringify(arg) : arg;
                }).join(' ') + '\\n';

                consoleOutput.scrollTop = consoleOutput.scrollHeight;
            };

            console.error = function() {
                var args = Array.prototype.slice.call(arguments);
                originalConsoleError.apply(console, args);

                consoleOutput.innerHTML += '<span style="color:red">> ' + args.map(function(arg) {
                    return typeof arg === 'object' ? JSON.stringify(arg) : arg;
                }).join(' ') + '</span>\\n';

                consoleOutput.scrollTop = consoleOutput.scrollHeight;
            };

            // Update status display
            function updateStatus(id, success, message) {
                var statusElement = document.getElementById(id).getElementsByTagName('span')[0];
                statusElement.textContent = message;
                statusElement.className = success ? 'success' : 'error';
            }

            // Load Phoenix
            document.getElementById('load-phoenix').addEventListener('click', function() {
                console.log('Loading Phoenix...');

                var script = document.createElement('script');
                script.src = 'https://cdn.jsdelivr.net/npm/phoenix@1.7.10/priv/static/phoenix.min.js';

                script.onload = function() {
                    console.log('Phoenix script loaded');

                    if (typeof window.Phoenix !== 'undefined') {
                        console.log('Phoenix object available in window');
                        updateStatus('phoenix-status', true, 'Loaded ✓');
                    } else {
                        console.error('Phoenix object NOT available in window!');
                        updateStatus('phoenix-status', false, 'Script loaded but object not available ✗');
                    }
                };

                script.onerror = function() {
                    console.error('Failed to load Phoenix script');
                    updateStatus('phoenix-status', false, 'Failed to load ✗');
                };

                document.head.appendChild(script);
            });

            // Load LiveView
            document.getElementById('load-liveview').addEventListener('click', function() {
                if (typeof window.Phoenix === 'undefined') {
                    console.error('Phoenix must be loaded first');
                    return;
                }

                console.log('Loading LiveView...');

                var script = document.createElement('script');
                script.src = 'https://cdn.jsdelivr.net/npm/phoenix_live_view@0.20.1/priv/static/phoenix_live_view.min.js';

                script.onload = function() {
                    console.log('LiveView script loaded');

                    if (window.Phoenix && window.Phoenix.LiveView) {
                        console.log('Phoenix.LiveView object available');
                        updateStatus('liveview-status', true, 'Loaded ✓');
                    } else {
                        console.error('Phoenix.LiveView object NOT available!');
                        updateStatus('liveview-status', false, 'Script loaded but object not available ✗');
                    }
                };

                script.onerror = function() {
                    console.error('Failed to load LiveView script');
                    updateStatus('liveview-status', false, 'Failed to load ✗');
                };

                document.head.appendChild(script);
            });

            // Initialize LiveView
            document.getElementById('init-liveview').addEventListener('click', function() {
                if (!window.Phoenix || !window.Phoenix.LiveView) {
                    console.error('Phoenix and LiveView must be loaded first');
                    return;
                }

                console.log('Initializing LiveView...');

                try {
                    // Get CSRF token
                    var csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
                    console.log('CSRF token:', csrfToken.substring(0, 10) + '...');

                    // Create LiveSocket
                    window.liveSocket = new window.Phoenix.LiveView.LiveSocket(
                        '/live',
                        window.Phoenix.Socket,
                        { params: { _csrf_token: csrfToken } }
                    );

                    console.log('LiveSocket created successfully');
                    updateStatus('socket-status', true, 'Initialized ✓');
                } catch (e) {
                    console.error('Error initializing LiveSocket:', e.message);
                    updateStatus('socket-status', false, 'Initialization failed ✗');
                }
            });

            // Test connection
            document.getElementById('test-connection').addEventListener('click', function() {
                if (!window.liveSocket) {
                    console.error('LiveSocket must be initialized first');
                    return;
                }

                console.log('Testing connection...');

                try {
                    // Connect LiveSocket
                    window.liveSocket.connect();

                    // Check connection after a short delay
                    setTimeout(function() {
                        try {
                            if (window.liveSocket.isConnected()) {
                                console.log('LiveSocket connected successfully');
                                updateStatus('connection-status', true, 'Connected ✓');
                            } else {
                                console.log('LiveSocket not connected');
                                updateStatus('connection-status', false, 'Failed to connect ✗');
                            }
                        } catch (e) {
                            console.error('Error checking connection:', e.message);
                            updateStatus('connection-status', false, 'Error checking connection ✗');
                        }
                    }, 1000);
                } catch (e) {
                    console.error('Error connecting LiveSocket:', e.message);
                    updateStatus('connection-status', false, 'Connection error ✗');
                }
            });

            console.log('Test page loaded at ' + new Date().toISOString());
        </script>
    </body>
    </html>
    """)
  end
end
