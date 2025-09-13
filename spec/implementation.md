# Tideland Ledger - Implementation Guide

Copyright 2024 Frank Mueller / Tideland / Oldenburg / Germany

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

## Purpose and Intention

This document provides a comprehensive, phase-by-phase implementation guide for the Tideland Ledger system. It serves as a roadmap that demonstrates how to build the complete system incrementally, with each phase being testable and verifiable before proceeding to the next.

### Goals of This Document

1. **Incremental Development**: Break the complex system into manageable, testable phases
2. **Risk Reduction**: Validate each phase works correctly before adding complexity
3. **Quality Assurance**: Define clear testing criteria and verification points
4. **Learning Path**: Provide a structured approach for Elixir/Phoenix learning
5. **Specification Compliance**: Ensure implementation matches the formal requirements

### How to Use This Guide

- Each phase builds upon the previous ones
- **Always complete the testing phase** before moving to the next implementation phase
- Use the verification checklists to confirm phase completion
- The "T.B.D." sections indicate phases not yet detailed but planned for future implementation

### Implementation Philosophy

This guide follows these principles:
- **Test Early, Test Often**: Every phase has immediate verification
- **Fail Fast**: Catch issues early before they compound
- **Specification Driven**: All implementation follows the formal specification
- **Phoenix Best Practices**: Follow Elixir/OTP and Phoenix conventions
- **German UI, English Code**: UI in German, code and URLs in English

## Phase Overview

### Foundation Phases (Core System)

#### Phase F1: Project Setup and Configuration
**Status**: T.B.D.
**Scope**: Initial Mix project, dependencies, basic configuration
**Testing**: Compilation, dependency resolution

#### Phase F2: Database Schema and Migrations
**Status**: T.B.D.
**Scope**: Ecto setup, SQLite configuration, all database tables
**Testing**: Migration execution, constraint verification

#### Phase F3: Core Business Logic Implementation
**Status**: T.B.D.
**Scope**: Amount type, contexts (Auth, Accounts, Transactions, Templates)
**Testing**: Unit tests for business logic, integration tests

### Web UI Phases (Phoenix Implementation)

#### Phase W1: Core Phoenix Infrastructure
**Status**: Documented (see detailed implementation below)
**Scope**: Endpoint, Router, basic configuration
**Testing**: Server startup, basic HTTP responses

#### Phase W2: Core UI Components & Layouts
**Status**: Documented (see detailed implementation below)
**Scope**: Base layouts, navigation, CSS styling
**Testing**: Visual verification, responsive design

#### Phase W3: Authentication Web Layer
**Status**: Documented (see detailed implementation below)
**Scope**: Login/logout, session management, authentication plugs
**Testing**: Authentication flows, session persistence

#### Phase W4: Core Business UIs
**Status**: Documented (see detailed implementation below)
**Scope**: Dashboard, Entry management, Account management, Templates
**Testing**: CRUD operations, LiveView interactions

#### Phase W5: Reporting & Advanced Features
**Status**: Documented (see detailed implementation below)
**Scope**: Report generation, exports, advanced UI features
**Testing**: Report accuracy, export functionality

#### Phase W6: Internationalization & Polish
**Status**: Documented (see detailed implementation below)
**Scope**: German translations, accessibility, performance
**Testing**: Translation completeness, accessibility compliance

### Advanced Phases (Future Enhancements)

#### Phase A1: CSV Import/Export
**Status**: T.B.D.
**Scope**: Import wizard, CSV parsing, export enhancements
**Testing**: Import accuracy, data validation

#### Phase A2: Advanced Reporting
**Status**: T.B.D.
**Scope**: Additional report types, dashboards, analytics
**Testing**: Report accuracy, performance

#### Phase A3: API Layer
**Status**: T.B.D.
**Scope**: REST API, JSON responses (if needed)
**Testing**: API functionality, authentication

#### Phase A4: Performance Optimization
**Status**: T.B.D.
**Scope**: Query optimization, caching, large dataset handling
**Testing**: Load testing, performance benchmarks

---

## Detailed Phoenix Web UI Implementation Phases

### Phase W1: Core Phoenix Infrastructure

#### Implementation Scope
- Phoenix Endpoint with LiveView support
- Basic Router with authentication pipelines
- Web configuration (sessions, CSRF, static assets)
- Enable web server in Application supervision tree

#### Files to Create/Modify
```
lib/ledger_web/
├── endpoint.ex           # Phoenix.Endpoint configuration
├── router.ex             # Route definitions and pipelines
└── gettext.ex            # Internationalization setup

config/
├── config.exs            # Basic web configuration
├── dev.exs               # Development-specific settings
└── prod.exs              # Production configuration (if needed)

lib/ledger/application.ex # Enable endpoint in supervision tree
```

#### Implementation Steps
1. **Create Endpoint** (`lib/ledger_web/endpoint.ex`)
   ```elixir
   defmodule LedgerWeb.Endpoint do
     use Phoenix.Endpoint, otp_app: :ledger

     # Socket for LiveView
     socket "/live", Phoenix.LiveView.Socket,
       websocket: [connect_info: [session: @session_options]]

     # Static asset serving
     plug Plug.Static,
       at: "/",
       from: :ledger,
       gzip: false,
       only: LedgerWeb.static_paths()

     # Session configuration
     plug Plug.Session, @session_options
     plug LedgerWeb.Router
   end
   ```

2. **Create Basic Router** (`lib/ledger_web/router.ex`)
   ```elixir
   defmodule LedgerWeb.Router do
     use LedgerWeb, :router

     pipeline :browser do
       plug :accepts, ["html"]
       plug :fetch_session
       plug :fetch_live_flash
       plug :put_root_layout, html: {LedgerWeb.Layouts, :root}
       plug :protect_from_forgery
       plug :put_secure_browser_headers
     end

     scope "/", LedgerWeb do
       pipe_through :browser

       get "/", PageController, :home
     end
   end
   ```

3. **Update Application** (`lib/ledger/application.ex`)
   ```elixir
   # Uncomment the endpoint in children list
   LedgerWeb.Endpoint,
   ```

4. **Add Web Configuration** (`config/config.exs`, `config/dev.exs`)

#### Testing Phase W1

**Automated Setup Test:**
```bash
# Verify dependencies
mix deps.get
mix compile
```

**Live Testing:**
```bash
# Start server
mix phx.server
```

**Verification Checklist:**
- [ ] Server starts on http://localhost:4000 without errors
- [ ] Browser shows "Phoenix is working" or basic page
- [ ] WebSocket connection established (check dev tools)
- [ ] Static assets serve from /assets/
- [ ] No compilation warnings or errors

**Test Commands:**
```bash
# Test basic HTTP response
curl http://localhost:4000

# Test static assets
curl http://localhost:4000/assets/app.css

# Check routes
mix phx.routes

# Verify endpoint configuration
mix app.config | grep -i endpoint
```

**Expected Results:**
- HTTP 200 responses for basic routes
- WebSocket connection in browser dev tools
- Clean server startup with no errors

---

### Phase W2: Core UI Components & Layouts

#### Implementation Scope
- Root and application layouts with navigation structure
- Core UI components (forms, buttons, tables)
- CSS styling following terminal-like design specification
- Responsive layout system

#### Files to Create
```
lib/ledger_web/components/
├── layouts/
│   ├── root.html.heex    # Base HTML document structure
│   └── app.html.heex     # Application layout with navigation
├── layouts.ex            # Layout module
└── core_components.ex    # Reusable UI components

priv/static/
├── css/
│   └── app.css           # Main stylesheet with terminal design
├── js/
│   └── app.js            # Minimal JavaScript (LiveView client)
└── images/
    └── favicon.ico       # Application favicon

assets/                   # Asset source files (if using build pipeline)
├── css/
│   └── app.css
└── js/
    └── app.js
```

#### Implementation Steps

1. **Create Root Layout** (`lib/ledger_web/components/layouts/root.html.heex`)
   ```html
   <!DOCTYPE html>
   <html lang="de" class="[scrollbar-gutter:stable]">
     <head>
       <meta charset="utf-8" />
       <meta name="viewport" content="width=device-width, initial-scale=1" />
       <meta name="csrf-token" content={get_csrf_token()} />
       <.live_title suffix=" · Tideland Ledger">
         <%= assigns[:page_title] || "Ledger" %>
       </.live_title>
       <link phx-track-static rel="stylesheet" href={~p"/assets/app.css"} />
       <script defer phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
     </head>
     <body class="bg-white antialiased">
       <%= @inner_content %>
     </body>
   </html>
   ```

2. **Create App Layout** (`lib/ledger_web/components/layouts/app.html.heex`)
   ```html
   <div class="container">
     <header class="header">
       <h1>Tideland Ledger</h1>
       <div class="user-info">
         <%= if assigns[:current_user] do %>
           <span><%= @current_user.name %></span>
           <.link href={~p"/logout"}>Abmelden</.link>
         <% end %>
       </div>
     </header>

     <nav class="menu">
       <.menu_item href={~p"/dashboard"} active={@active_menu == :dashboard}>
         Übersicht
       </.menu_item>
       <.menu_item href={~p"/entries"} active={@active_menu == :entries}>
         Buchungen
       </.menu_item>
       <.menu_item href={~p"/accounts"} active={@active_menu == :accounts}>
         Konten
       </.menu_item>
       <!-- More menu items -->
     </nav>

     <main class="content">
       <.flash_group flash={@flash} />
       <%= @inner_content %>
     </main>
   </div>
   ```

3. **Create Terminal-Style CSS** (`priv/static/css/app.css`)
   ```css
   :root {
     --primary-color: #1a1a1a;
     --background-color: #ffffff;
     --border-color: #cccccc;
     --error-color: #cc0000;
     --success-color: #008800;
     --font-family: 'Monaco', 'Consolas', monospace;
   }

   .container {
     display: grid;
     grid-template-columns: 200px 1fr;
     grid-template-rows: auto 1fr;
     min-height: 100vh;
     font-family: var(--font-family);
   }

   .menu {
     grid-row: 2;
     border-right: 1px solid var(--border-color);
     background: var(--background-color);
   }

   .menu-item {
     display: block;
     width: 100%;
     padding: 1rem;
     text-decoration: none;
     color: var(--primary-color);
     border-bottom: 1px solid var(--border-color);
   }

   .menu-item:hover,
   .menu-item.active {
     background: var(--primary-color);
     color: var(--background-color);
   }
   ```

4. **Core Components** (`lib/ledger_web/components/core_components.ex`)
   ```elixir
   defmodule LedgerWeb.CoreComponents do
     use Phoenix.Component

     attr :href, :string, required: true
     attr :active, :boolean, default: false
     slot :inner_block, required: true

     def menu_item(assigns) do
       ~H"""
       <.link
         href={@href}
         class={["menu-item", @active && "active"]}
       >
         <%= render_slot(@inner_block) %>
       </.link>
       """
     end

     # Additional form components, buttons, etc.
   end
   ```

#### Testing Phase W2

**Visual Verification:**
```bash
mix phx.server
# Visit http://localhost:4000
```

**Verification Checklist:**
- [ ] Navigation menu appears on left side
- [ ] Terminal-like styling is applied (monospace font, flat design)
- [ ] Menu items are clickable (even if routes don't exist yet)
- [ ] Responsive layout works on mobile (menu collapses/adapts)
- [ ] CSS loads without 404 errors
- [ ] German text displays correctly
- [ ] Layout matches wui-design.md specifications

**Browser Testing Steps:**
1. **Desktop View**:
   - Navigation should be vertical on left
   - Content area should fill remaining space
   - Hover effects work on menu items

2. **Mobile View**:
   - Resize browser to < 768px width
   - Layout should adapt (menu stacking or collapse)
   - Text remains readable

3. **CSS Verification**:
   - Right-click → Inspect Element
   - Verify CSS custom properties are applied
   - Check for console errors

**Test Commands:**
```bash
# Verify CSS asset compilation
mix assets.build

# Check static file serving
curl http://localhost:4000/assets/app.css | head -10

# Test responsive design with different user agents
curl -H "User-Agent: Mobile" http://localhost:4000
```

---

### Phase W3: Authentication Web Layer

#### Implementation Scope
- Login/logout controllers or LiveViews
- Authentication plugs and session management
- User management interface (admin only)
- Integration with existing Auth context

#### Files to Create
```
lib/ledger_web/
├── controllers/
│   └── auth_controller.ex      # Login/logout handling
├── live/
│   ├── login_live.ex           # Login form LiveView
│   └── user_live/              # User management (admin)
│       ├── index.ex
│       └── form.ex
└── plugs/
    ├── auth.ex                 # Authentication plug
    └── require_admin.ex        # Authorization plug
```

#### Implementation Steps

1. **Authentication Plug** (`lib/ledger_web/plugs/auth.ex`)
   ```elixir
   defmodule LedgerWeb.Plugs.Auth do
     import Plug.Conn
     import Phoenix.Controller

     def init(opts), do: opts

     def call(conn, _opts) do
       case get_session(conn, :user_id) do
         nil ->
           conn
         user_id ->
           case Ledger.Auth.get_user(user_id) do
             {:ok, user} -> assign(conn, :current_user, user)
             {:error, _} -> clear_session(conn)
           end
       end
     end

     def require_authenticated_user(conn, _opts) do
       if conn.assigns[:current_user] do
         conn
       else
         conn
         |> put_flash(:error, "Sie müssen sich anmelden.")
         |> redirect(to: "/login")
         |> halt()
       end
     end
   end
   ```

2. **Login LiveView** (`lib/ledger_web/live/login_live.ex`)
   ```elixir
   defmodule LedgerWeb.LoginLive do
     use LedgerWeb, :live_view

     def mount(_params, _session, socket) do
       {:ok, assign(socket, form: to_form(%{}))}
     end

     def render(assigns) do
       ~H"""
       <div class="login-container">
         <h2>Anmeldung</h2>

         <.form for={@form} phx-submit="login">
           <.input field={@form[:username]} label="Benutzername" required />
           <.input
             field={@form[:password]}
             type="password"
             label="Passwort"
             required
           />
           <.button type="submit">Anmelden</.button>
         </.form>
       </div>
       """
     end

     def handle_event("login", %{"username" => username, "password" => password}, socket) do
       case Ledger.Auth.authenticate_user(username, password) do
         {:ok, user} ->
           {:noreply,
            socket
            |> put_session(:user_id, user.id)
            |> put_flash(:info, "Erfolgreich angemeldet.")
            |> push_navigate(to: "/dashboard")}

         {:error, _reason} ->
           {:noreply,
            socket
            |> put_flash(:error, "Ungültige Anmeldedaten.")
            |> assign(form: to_form(%{}))}
       end
     end
   end
   ```

3. **Update Router** (`lib/ledger_web/router.ex`)
   ```elixir
   pipeline :auth do
     plug LedgerWeb.Plugs.Auth
   end

   pipeline :require_auth do
     plug :auth
     plug LedgerWeb.Plugs.Auth, :require_authenticated_user
   end

   scope "/", LedgerWeb do
     pipe_through [:browser, :auth]

     live "/login", LoginLive
     post "/logout", AuthController, :logout
   end

   scope "/", LedgerWeb do
     pipe_through [:browser, :require_auth]

     live "/dashboard", DashboardLive
     # Protected routes
   end
   ```

#### Testing Phase W3

**Authentication Flow Testing:**
```bash
mix phx.server
```

**Manual Testing Steps:**
1. **Login Flow**:
   - Visit http://localhost:4000/login
   - Try invalid credentials → should show error
   - Try valid admin credentials → should redirect to dashboard
   - Check session persists across page refreshes

2. **Authorization Testing**:
   - Visit protected route without login → should redirect to login
   - Login as admin → should access admin features
   - Login as non-admin → admin features should be hidden/blocked

3. **Session Management**:
   - Login → close browser → reopen → should still be logged in
   - Logout → should redirect to login page
   - Try accessing protected route after logout → should require login

**Verification Checklist:**
- [ ] Login form renders and submits
- [ ] Valid credentials authenticate successfully
- [ ] Invalid credentials show error message
- [ ] Session persists across requests
- [ ] Protected routes require authentication
- [ ] Logout clears session and redirects
- [ ] Admin-only features respect role permissions

**Test Commands:**
```bash
# Test login endpoint
curl -X POST http://localhost:4000/login \
  -d "username=admin" \
  -d "password=password" \
  -c cookies.txt

# Test protected route with session
curl -b cookies.txt http://localhost:4000/dashboard

# Test logout
curl -X POST -b cookies.txt http://localhost:4000/logout
```

**Database Verification:**
```bash
# Check admin user was created
mix ecto.reset
mix phx.server
# Admin should be available for login

# Check session storage
# Login via browser, then check sessions table
```

---

### Phase W4: Core Business UIs

This phase implements the main user interfaces for ledger operations, broken into sub-phases for incremental testing.

#### Phase W4.1: Dashboard Implementation

**Scope**: Main overview page with account balances and recent entries

**Files to Create:**
```
lib/ledger_web/live/
├── dashboard_live.ex           # Main dashboard LiveView
└── components/
    ├── account_summary.ex      # Account balance display
    └── recent_entries.ex       # Recent entries list
```

**Implementation:**
```elixir
defmodule LedgerWeb.DashboardLive do
  use LedgerWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Übersicht")
     |> assign(:active_menu, :dashboard)
     |> load_dashboard_data()}
  end

  defp load_dashboard_data(socket) do
    socket
    |> assign(:account_balances, Ledger.Accounts.list_account_balances())
    |> assign(:recent_entries, Ledger.Transactions.list_recent_entries(limit: 10))
  end
end
```

**Testing W4.1:**
- [ ] Dashboard loads after login
- [ ] Account balances display (even if zero/empty)
- [ ] Recent entries show (even if none exist)
- [ ] Navigation highlighting works
- [ ] Page title shows correctly

#### Phase W4.2: Entry Management

**Scope**: Entry listing, creation, editing with LiveView real-time validation

**Files to Create:**
```
lib/ledger_web/live/entry_live/
├── index.ex                    # Entry listing
├── show.ex                     # Entry detail view
├── form.ex                     # Entry creation/editing form
└── position_component.ex       # Position input component
```

**Key Features to Test:**
- Real-time sum calculation as user types amounts
- Dynamic addition/removal of positions
- Account selection with search
- Template application
- Form validation and error display

**Testing W4.2:**
```bash
# Test entry creation flow
# 1. Visit /entries/new
# 2. Fill form with positions
# 3. Verify sum updates in real-time
# 4. Submit valid entry → should save to database
# 5. Submit invalid entry → should show errors
```

**LiveView Specific Tests:**
- Type in amount field → sum updates immediately
- Add position → new row appears
- Remove position → row disappears and sum updates
- Select template → form populates with template data

#### Phase W4.3: Account Management

**Scope**: Hierarchical account display, creation, editing

**Files to Create:**
```
lib/ledger_web/live/account_live/
├── index.ex                    # Hierarchical account listing
├── show.ex                     # Account detail with entry history
└── form.ex                     # Account creation/editing
```

**Testing W4.3:**
- [ ] Accounts display in hierarchical structure
- [ ] Account paths show correctly (e.g., "Vermögen : Bank : Girokonto")
- [ ] Account creation validates hierarchy
- [ ] Account detail shows related entries
- [ ] Search/filtering works

#### Phase W4.4: Template Management

**Scope**: Template listing, creation, versioning system

**Files to Create:**
```
lib/ledger_web/live/template_live/
├── index.ex                    # Template and version listing
├── form.ex                     # Template creation
└── version_form.ex             # New version creation
```

**Testing W4.4:**
- [ ] Templates list with all versions
- [ ] New template creation works
- [ ] Version creation from existing template
- [ ] Template application in entry form
- [ ] Fraction-based position calculations

#### Combined Testing Phase W4

**Integration Testing:**
1. **Complete Workflow Test:**
   ```bash
   # Create accounts
   # Create template
   # Create entry using template
   # Verify entry appears in account history
   # Generate report including the entry
   ```

2. **Data Consistency:**
   - Create entry → verify positions sum to zero
   - Apply template → verify calculations are correct
   - Edit account → verify hierarchy maintained

3. **UI Consistency:**
   - All pages use same navigation
   - German translations consistent
   - Error handling works across all forms

**Verification Checklist:**
- [ ] All CRUD operations work for entries, accounts, templates
- [ ] LiveView interactions are responsive
- [ ] Form validation prevents invalid data
- [ ] Navigation between related items works
- [ ] Database constraints are respected
- [ ] German text displays correctly throughout

---

### Phase W5: Reporting & Advanced Features

#### Implementation Scope
- Trial balance and other standard reports
- CSV export functionality
- Search and filtering across the application
- Keyboard shortcuts implementation

#### Files to Create
```
lib/ledger_web/live/report_live/
├── index.ex                    # Report selection and configuration
├── trial_balance.ex            # Trial balance report
└── export_controller.ex        # CSV export handling
```

#### Testing Phase W5
- [ ] Reports generate with correct data
- [ ] CSV exports download successfully
- [ ] Search functionality works
- [ ] Keyboard shortcuts respond correctly

---

### Phase W6: Internationalization & Polish

#### Implementation Scope
- Complete German translation setup
- Accessibility improvements
- Performance optimization
- Mobile responsiveness refinement

#### Testing Phase W6
- [ ] All UI text translated to German
- [ ] Accessibility standards met
- [ ] Performance benchmarks achieved
- [ ] Mobile experience polished

---

## Testing Infrastructure

### Automated Test Suite Structure

```
test/
├── ledger_web/
│   ├── controllers/
│   │   └── auth_controller_test.exs
│   ├── live/
│   │   ├── dashboard_live_test.exs
│   │   ├── entry_live_test.exs
│   │   └── account_live_test.exs
│   └── integration/
│       └── authentication_test.exs
└── support/
    ├── conn_case.ex
    └── live_case.ex
```

### Performance Testing

```bash
# Load testing with httperf or similar
httperf --server localhost --port 4000 --num-calls 1000 --rate 10

# Memory usage monitoring
:observer.start()  # In IEx session
```

### Browser Testing Matrix

- **Desktop**: Chrome, Firefox, Safari
- **Mobile**: iOS Safari, Android Chrome
- **Accessibility**: Screen reader testing, keyboard navigation

## Summary

This implementation guide provides a structured approach to building the Tideland Ledger web interface. Each phase is designed to be:

- **Independently testable**: Can verify functionality before proceeding
- **Incrementally valuable**: Each phase adds working features
- **Specification compliant**: Follows all design and requirement documents
- **Quality assured**: Comprehensive testing at each stage

The detailed phases (W1-W6) provide specific implementation steps and testing procedures, while the T.B.D. phases outline the complete system roadmap for future development.
