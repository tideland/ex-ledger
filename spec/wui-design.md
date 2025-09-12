# Tideland Ledger - Web User Interface (WUI) Design

## 1. Overview

This document describes the web user interface design for the Tideland Ledger application. The WUI is built using pure Phoenix/Elixir without any external JavaScript frameworks or Node.js dependencies. The design philosophy emphasizes simplicity, functionality, and a clean, terminal-like interface.

## 2. Design Principles

### 2.1 Core Principles

- **Pure Phoenix**: No Node.js, npm, or external JavaScript frameworks
- **Server-Side Focus**: Use Phoenix LiveView for all interactivity
- **Minimal Styling**: Simple, flat design reminiscent of mainframe terminals or CLI tools
- **German Language**: All UI text in German (source code remains in English)
- **Keyboard-Friendly**: Support keyboard navigation and shortcuts
- **Responsive**: Works on different screen sizes without complex CSS

### 2.2 Visual Design Guidelines

- **Flat Design**: No gradients, shadows, or 3D effects
- **High Contrast**: Clear text on contrasting backgrounds
- **Consistent Spacing**: Use CSS Grid or Flexbox for layout
- **Minimal Colors**: Primary color for actions, neutral grays for structure
- **Clear Typography**: System fonts, readable sizes

### 2.3 Interaction Patterns

- **Immediate Feedback**: LiveView for real-time validation
- **Clear Actions**: Obvious primary and secondary actions
- **Error Prevention**: Validate input before submission
- **Undo Support**: Where appropriate (e.g., deleting positions)

### 2.4 URL Naming Conventions

- **English Only**: All URL paths and parameters must be in English
- **Lowercase**: URLs use lowercase letters exclusively
- **Dash-Separated**: CamelCase converts to dash-separated format
- **Descriptive Verbs**: Operations use clear English action words
- **RESTful Patterns**: Follow standard REST conventions where applicable

**URL Pattern Examples**:

- `/dashboard` - Main overview page
- `/entries` - Entry listing
- `/entries/new` - Create new entry
- `/entries/:id/edit` - Edit specific entry
- `/accounts` - Account listing
- `/accounts/:id` - Account detail view
- `/templates` - Template listing
- `/templates/new` - Create new template
- `/templates/:id/create-version` - Create new template version
- `/reports/trial-balance` - Trial balance report
- `/users` - User management (admin only)

## 3. Application Layout

### 3.1 Base Layout Structure

```
┌─────────────────────────────────────────────────────────────┐
│ Tideland Ledger                           [Benutzer] [Abmelden] │
├────────────────┬────────────────────────────────────────────┤
│                │                                             │
│ Übersicht      │                                             │
│                │                                             │
│ Buchungen      │         Main Content Area                  │
│                │                                             │
│ Konten         │                                             │
│                │                                             │
│ Vorlagen       │                                             │
│                │                                             │
│ Berichte       │                                             │
│                │                                             │
│ Benutzer       │                                             │
│                │                                             │
├────────────────┴────────────────────────────────────────────┤
│ Status: [Messages]                      [Version] [Help]    │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Navigation Menu

- Vertical menu on the left side
- Menu items as full-height clickable blocks
- Active item highlighted with primary color
- No dropdown menus - all navigation is flat
- Fixed width for consistent layout

### 3.3 CSS Structure

```css
/* Minimal CSS - stored in priv/static/css/app.css */
:root {
  --primary-color: #1a1a1a;
  --background-color: #ffffff;
  --border-color: #cccccc;
  --error-color: #cc0000;
  --success-color: #008800;
  --font-family: system-ui, -apple-system, sans-serif;
}

/* Simple grid-based layout with vertical menu */
.container {
  display: grid;
  grid-template-columns: 200px 1fr;
  grid-template-rows: auto 1fr auto;
  min-height: 100vh;
}

.menu {
  grid-row: 2;
  border-right: 1px solid var(--border-color);
}

.content {
  grid-row: 2;
  padding: 1rem;
}

/* Flat button style for vertical menu items */
.menu-item {
  display: block;
  width: 100%;
  padding: 1rem;
  text-align: left;
  border: none;
  background: none;
  cursor: pointer;
}

.menu-item:hover {
  background-color: var(--border-color);
}

.menu-item.active {
  background-color: var(--primary-color);
  color: var(--background-color);
}
```

## 4. LiveView State Management

### 4.1 Entry Creation State Chart

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    Draft    │────▶│  Validated  │────▶│   Posted    │
│   (Entwurf) │     │ (Geprüft)   │     │  (Gebucht)  │
└─────────────┘     └─────────────┘     └─────────────┘
       │                    │                    │
       │                    │                    │
       ▼                    ▼                    ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Editing   │     │    Error    │     │   Void      │
│ (Bearbeiten)│     │   (Fehler)  │     │ (Storniert) │
└─────────────┘     └─────────────┘     └─────────────┘
```

### 4.2 LiveView Component States

```elixir
# Entry creation LiveView states
defmodule LedgerWeb.EntryLive do
  use LedgerWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket,
      state: :draft,
      entry: %Entry{},
      errors: [],
      accounts: list_accounts()
    )}
  end

  # State transitions
  def handle_event("validate", %{"entry" => params}, socket) do
    case validate_entry(params) do
      {:ok, entry} ->
        {:noreply, assign(socket, state: :validated, entry: entry)}
      {:error, errors} ->
        {:noreply, assign(socket, state: :error, errors: errors)}
    end
  end

  def handle_event("post", _params, socket) do
    case post_entry(socket.assigns.entry) do
      {:ok, entry} ->
        {:noreply,
         socket
         |> assign(state: :posted, entry: entry)
         |> put_flash(:info, "Buchung erfolgreich")
         |> push_redirect(to: Routes.entry_path(socket, :show, entry))}
      {:error, errors} ->
        {:noreply, assign(socket, state: :error, errors: errors)}
    end
  end
end
```

### 4.3 Form Validation Flow

```
User Input ──▶ LiveView Validation ──▶ Visual Feedback
    │                  │                      │
    ▼                  ▼                      ▼
┌─────────┐    ┌──────────────┐      ┌──────────────┐
│ Typing  │    │ Debounce     │      │ Field State  │
│         │    │ (200ms)      │      │ ✓ Valid      │
│         │    │              │      │ ✗ Invalid    │
│         │    │              │      │ ⏳ Checking   │
└─────────┘    └──────────────┘      └──────────────┘
```

## 5. Page Layouts

### 5.1 Dashboard (Übersicht)

padding: 1rem;
text-align: left;
text-decoration: none;
border-bottom: 1px solid var(--border-color);
background: var(--background-color);
width: 100%;
}

.menu-item:hover,
.menu-item.active {
background: var(--primary-color);
color: var(--background-color);
}

```

## 4. Page Designs

### 4.1 Dashboard (Übersicht)

**Purpose**: Quick overview of ledger status and recent activity

**Layout**:

```

┌─────────────────────────────┬─────────────────────────────┐
│ Kontensalden │ Letzte Buchungen │
│ │ │
│ Bank: 12.500,00 € │ 15.01. Miete -1.500,00 │
│ Kasse: 250,00 € │ 14.01. Material -125,50 │
│ Forderungen: 5.000,00 € │ 13.01. Zahlung +2.000,00 │
│ │ │
│ [Alle Konten anzeigen] │ [Alle Buchungen anzeigen] │
└─────────────────────────────┴─────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ Schnellaktionen │
│ │
│ [Neue Buchung] [Vorlage anwenden] [Bericht erstellen] │
└─────────────────────────────────────────────────────────────┘

```

**LiveView Features**:

- Real-time balance updates
- Click on account to view details
- Click on entry to edit

### 4.2 Entry Creation (Neue Buchung)

**Purpose**: Create new bookkeeping entries

**Layout**:

```

┌─────────────────────────────────────────────────────────────┐
│ Neue Buchung erstellen │
├─────────────────────────────────────────────────────────────┤
│ Datum: [____-__-__] Belegnr: [_______________] │
│ │
│ Beschreibung: [____________________________________________]│
│ │
│ Vorlage: [Keine ▼] Version: [Aktuelle ▼] │
│ │
│ Hinweis: Bei Auswahl einer Vorlage werden verfügbare │
│ Versionen im Versions-Dropdown angezeigt. │
├─────────────────────────────────────────────────────────────┤
│ Positionen: │
│ │
│ Konto Betrag │
│ [_________________________________ ▼] [_______] │
│ [_________________________________ ▼] [_______] │
│ │
│ [+ Position hinzufügen] │
│ │
│ Summe: 0,00 │
├─────────────────────────────────────────────────────────────┤
│ [Abbrechen] [Buchung speichern]│
└─────────────────────────────────────────────────────────────┘

````

**LiveView Features**:

- Real-time sum calculation (must equal zero)
- Account dropdown with search (shows full hierarchical path)
- Dynamic position adding/removing
- Template selection dynamically loads available versions
- Template application updates form with versioned data
- Validation messages inline
- Signed amounts (+/- instead of debit/credit columns)

**Account Entry**:

- Accounts shown as full hierarchical paths: "Vermögen : Bank : Girokonto"
- Searchable by any part of the path
- Wide input field to accommodate long paths

**Amount Entry**:

- Single amount field per position
- Positive amounts (e.g., +1500,00 or just 1500,00)
- Negative amounts (e.g., -1500,00)
- No separate debit/credit columns

**Template Version Selection Behavior**:

```elixir
# When template is selected
def handle_event("select_template", %{"template" => template_name}, socket) do
  versions = Ledger.Templates.list_versions(template_name)
  latest_version = List.first(versions)

  {:noreply,
   socket
   |> assign(selected_template: template_name)
   |> assign(available_versions: versions)
   |> assign(selected_version: latest_version)
   |> apply_template_preview(template_name, latest_version)}
end

# When version is changed
def handle_event("select_version", %{"version" => version}, socket) do
  {:noreply,
   socket
   |> assign(selected_version: version)
   |> apply_template_preview(socket.assigns.selected_template, version)}
end
````

### 4.3 Account Management (Konten)

**Purpose**: Manage chart of accounts

**Layout**:

```

┌─────────────────────────────────────────────────────────────┐
│ Kontenplan │
├─────────────────────────────────────────────────────────────┤
│ [Neues Konto] Suche: [_______________] [Inaktive zeigen]│
├─────────────────────────────────────────────────────────────┤
│ Kontopfad Saldo │
│ ────────────────────────────────────────────────────────── │
│ Vermögen : Bargeld 250,00 € │
│ Vermögen : Bank : Girokonto 12.500,00 € │
│ Vermögen : Bank : Sparkonto 25.000,00 € │
│ Vermögen : Forderungen 5.000,00 € │
│ ... │
└─────────────────────────────────────────────────────────────┘

```

**Click Actions**:

- Click row to view account details
- Double-click to edit account

### 4.4 Account Detail View

**Layout**:

```

┌─────────────────────────────────────────────────────────────┐
│ Konto: Vermögen : Bank : Girokonto │
├─────────────────────────────────────────────────────────────┤
│ Aktueller Saldo: 12.500,00 € │
│ │
│ Kontobewegungen: │
│ │
│ Datum Beschreibung Soll Haben Saldo │
│ ──────────────────────────────────────────────────────────│
│ 15.01.24 Miete 1.500,00 12.500,00│
│ 14.01.24 Kundenzahlung 2.000,00 14.000,00│
│ ... │
│ │
│ [Zurück] [Bearbeiten] [Bericht exportieren] │
└─────────────────────────────────────────────────────────────┘

```

### 4.5 Template Management (Vorlagen)

**Purpose**: Create and manage entry templates

**Layout**:

```

┌─────────────────────────────────────────────────────────────┐
│ Buchungsvorlagen │
├─────────────────────────────────────────────────────────────┤
│ [Neue Vorlage] │
├─────────────────────────────────────────────────────────────┤
│ Name Version Positionen Aktionen │
│ ────────────────────────────────────────────────────────── │
│ Monatliche Miete v2 2 [▶] [📋] [+] │
│ Monatliche Miete v1 2 [▶] [📋] │
│ Büromaterial v1 2 [▶] [📋] [+] │
│ Gehaltszahlung v3 4 [▶] [📋] [+] │
│ Gehaltszahlung v2 4 [▶] [📋] │
│ Gehaltszahlung v1 4 [▶] [📋] │
└─────────────────────────────────────────────────────────────┘

**Actions**:
- [▶] = Apply template (opens entry form with this version)
- [📋] = Copy to create new version
- [+] = Only shown for latest version (create next version)

**Note**: Templates cannot be edited or deleted, only new versions created.

```

### 4.6 Template Editor

**Layout**:

```

┌─────────────────────────────────────────────────────────────┐
│ Neue Vorlage Version erstellen │
├─────────────────────────────────────────────────────────────┤
│ Name: [Monatliche Miete___________________________________]│
│ Basiert auf: Monatliche Miete v2 │
│ Neue Version: v3 │
│ │
│ Standardbetrag: [1.500,00] □ Betrag variabel │
│ │
│ Positionen: │
│ │
│ Konto Anteil/Betrag │
│ [_________________________________ ▼] [1,00] │
│ [_________________________________ ▼] [-1,00] │
│ │
│ [+ Position] │
│ │
│ [Abbrechen] [Vorlage speichern]│
└─────────────────────────────────────────────────────────────┘

**Version Creation Rules**:
- New versions automatically increment (v1 → v2 → v3)
- All fields pre-filled from selected base version
- Changes create new version, original remains unchanged
- Version history maintained for audit trail

```

### 4.7 Reports (Berichte)

**Purpose**: Generate and view financial reports

**Layout**:

```

┌─────────────────────────────────────────────────────────────┐
│ Berichte │
├─────────────────────────────────────────────────────────────┤
│ Berichtstyp: [Probebilanz ▼] │
│ │
│ Zeitraum: [____-__-__] bis [____-__-__] │
│ │
│ [Bericht erstellen] │
├─────────────────────────────────────────────────────────────┤
│ Probebilanz │
│ 31.01.2024 │
│ │
│ Konto Bezeichnung Soll Haben │
│ ────────────────────────────────────────────────────────── │
│ Vermögen : Bargeld 250,00 │
│ Vermögen : Bank 12.500,00 │
│ Eigenkapital 30.000,00 │
│ ... │
│ ────────────────────────────────────────────────────────── │
│ Summen: 42.750,00 42.750,00 │
│ │
│ [Drucken] [Als CSV exportieren] │
└─────────────────────────────────────────────────────────────┘

```

### 4.8 User Management (Benutzer)

**Purpose**: Manage system users and their roles

**Layout**:

```

┌─────────────────────────────────────────────────────────────┐
│ Benutzerverwaltung │
├─────────────────────────────────────────────────────────────┤
│ [Neuer Benutzer] │
├─────────────────────────────────────────────────────────────┤
│ Benutzername Rolle Letzte Anmeldung Status │
│ ────────────────────────────────────────────────────────── │
│ admin Administrator 15.01.24 14:30 Aktiv │
│ mmueller Buchhalter 15.01.24 09:15 Aktiv │
│ kschmidt Betrachter 10.01.24 11:00 Aktiv │
│ │
│ Klicken zum Bearbeiten │
└─────────────────────────────────────────────────────────────┘

```

## 5. Form Patterns

### 5.1 Input Fields

```html
<!-- Text input with label -->
<div class="field">
  <label for="description">Beschreibung</label>
  <input type="text" id="description" name="description" />
</div>

<!-- Amount input with formatting and sign -->
<div class="field">
  <label for="amount">Betrag</label>
  <input type="text" id="amount" name="amount" pattern="[+-]?[0-9]+([,][0-9]{2})?" placeholder="+1.500,00 oder -1.500,00" />
</div>

<!-- Account input with wide field -->
<div class="field">
  <label for="account">Konto</label>
  <input type="text" id="account" name="account" class="account-input" placeholder="Vermögen : Bank : Girokonto" />
</div>

<!-- Date input -->
<div class="field">
  <label for="date">Datum</label>
  <input type="date" id="date" name="date" />
</div>
```

### 5.2 Validation Messages

```html
<!-- Field with error -->
<div class="field error">
  <label for="amount">Betrag</label>
  <input type="text" id="amount" name="amount" />
  <span class="error-message">Betrag muss positiv sein</span>
</div>

<!-- Form-level error -->
<div class="form-error">Die Buchung ist nicht ausgeglichen. Differenz: 10,00 €</div>
```

### 5.3 Button Patterns

```html
<!-- Primary action -->
<button type="submit" class="btn-primary">Speichern</button>

<!-- Secondary action -->
<button type="button" class="btn-secondary">Abbrechen</button>

<!-- Danger action -->
<button type="button" class="btn-danger">Löschen</button>

<!-- Icon button -->
<button type="button" class="btn-icon" title="Position entfernen">×</button>
```

## 6. LiveView Components

### 6.1 Entry Form Component

```elixir
defmodule LedgerWeb.EntryLive.FormComponent do
  use LedgerWeb, :live_component

  # Handles real-time validation
  # Dynamic position management
  # Template application
  # Balance calculation
end
```

### 6.2 Account Selector Component

```elixir
defmodule LedgerWeb.Components.AccountSelector do
  use Phoenix.Component

  # Searchable dropdown
  # Shows account code and name
  # Validates account exists
  # Can restrict to active accounts
end
```

### 6.3 Amount Input Component

```elixir
defmodule LedgerWeb.Components.AmountInput do
  use Phoenix.Component

  # Formats input as user types
  # Handles German decimal format (1.234,56)
  # Validates amount format with sign (+/-)
  # Supports both positive and negative amounts
  # Shows running sum in entry form
end
```

## 7. Navigation Flow

### 7.1 Main Navigation Paths

1. **Dashboard** (`/dashboard`) → Quick access to all major functions
2. **Entries** (`/entries`) → List → New (`/entries/new`) / Edit (`/entries/:id/edit`) → Save → Back to list
3. **Accounts** (`/accounts`) → List → Detail (`/accounts/:id`) → Edit (`/accounts/:id/edit`) → Save
4. **Templates** (`/templates`) → List → New (`/templates/new`) / Create Version (`/templates/:id/create-version`) → Apply in entry form
5. **Reports** (`/reports`) → Select type → Configure → Generate → Export

### 7.2 URL Structure and RESTful Patterns

**Resource-Based URLs**:

- `GET /entries` - List all entries
- `GET /entries/new` - Show entry creation form
- `POST /entries` - Create new entry
- `GET /entries/:id` - Show specific entry
- `GET /entries/:id/edit` - Show entry edit form
- `PUT /entries/:id` - Update specific entry
- `DELETE /entries/:id` - Void/delete entry

**Nested Resources**:

- `GET /templates/:id/create-version` - Create new version of template
- `POST /templates/:id/versions` - Save new template version
- `GET /accounts/:id/entries` - Show entries for specific account

### 7.3 Keyboard Shortcuts

- `Alt+N` - Neue Buchung (New entry) - navigates to `/entries/new`
- `Alt+K` - Konten (Accounts) - navigates to `/accounts`
- `Alt+B` - Berichte (Reports) - navigates to `/reports`
- `Tab` - Navigate between fields
- `Enter` - Submit form (when valid)
- `Esc` - Cancel/close dialog

## 8. Responsive Design

### 8.1 Breakpoints

- **Desktop**: 1024px and up - Full layout
- **Tablet**: 768px to 1023px - Simplified navigation
- **Mobile**: Below 768px - Single column, stacked layout

### 8.2 Mobile Adaptations

- Vertical menu collapses to hamburger
- Tables become cards on mobile
- Forms remain single column
- Buttons stack vertically
- Account paths may wrap on narrow screens

## 9. Error Handling

### 9.1 Validation Errors

- Show inline next to fields
- Highlight fields with errors
- Show summary at top of form
- Prevent submission until fixed

### 9.2 System Errors

- Show user-friendly message
- Log technical details
- Provide recovery action
- Never show stack traces to users

### 9.3 Permission Errors

- Clear message about lacking permission
- Suggest contacting administrator
- Redirect to allowed page

## 10. Performance Considerations

### 10.1 LiveView Optimization

- Use temporary assigns for large lists
- Paginate long lists (20-50 items per page)
- Debounce search inputs
- Stream updates for real-time data

### 10.2 Asset Optimization

- Minimal CSS file
- No JavaScript frameworks
- Inline critical CSS
- Use browser caching

## 11. Accessibility

### 11.1 Standards

- Semantic HTML
- Proper label associations
- Keyboard navigation support
- High contrast colors
- Clear focus indicators

### 11.2 Screen Reader Support

- Descriptive labels
- ARIA attributes where needed
- Status messages announced
- Logical heading hierarchy

## 12. Implementation Notes

### 12.1 Phoenix-Specific

- Use Phoenix.Component for reusable UI
- LiveView for all interactive forms
- Phoenix.HTML for form helpers
- Gettext for German translations

### 12.2 CSS Architecture

- Single `app.css` file
- CSS custom properties for theming
- Utility classes for common patterns
- No preprocessors or build tools

### 12.3 Template Structure

- Use `.heex` templates
- Function components for reuse
- Minimal inline styles
- Clear component boundaries

This WUI design provides a clean, functional interface that aligns with the project's goals of simplicity and learning while delivering a professional bookkeeping application.
