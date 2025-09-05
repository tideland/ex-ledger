# Tideland Ledger - Domain Specific Language (DSL) Design

## 1. Overview

This document outlines a domain-specific language for expressing ledger operations. The DSL aims to be:

- Human-readable and self-documenting
- Type-safe and validatable
- Suitable for both programmatic use and configuration files
- Translatable to Elixir implementation

## 2. Configuration

### 2.1 TOML Configuration

```
# config.toml
[application]
host = "localhost"
port = 4000

[database]
adapter = "sqlite3"
database = "./ledger.db"

[admin]
# Initial admin password hash
password_hash = "$2b$12$..."

[ui]
# Simple color customization
primary_color = "#1a1a1a"
background_color = "#ffffff"
```

## 3. Core Types

### 2.1 Amount

```
Amount = Decimal with precision 2

# Creating amounts
a1 = Amount.new(100.50)
a2 = Amount.new("50.25")
zero = Amount.zero()

# Amount operations (return new Amount instances)
a3 = Amount.add(a1, a2)           # 150.75
a4 = Amount.subtract(a1, a2)      # 50.25
a5 = Amount.multiply(a1, 2)       # 201.00
a6 = Amount.divide(a1, 3)         # 33.50 (rounded)
a7 = Amount.negate(a1)            # -100.50

# Comparisons
Amount.equal?(a1, a2)             # false
Amount.greater?(a1, a2)           # true
Amount.less?(a1, a2)              # false
Amount.is_zero?(zero)             # true

# Special operations
amounts = Amount.distribute(a1, 3)  # [33.50, 33.50, 33.50]
total = Amount.sum([a1, a2, a3])    # 301.25

# Display
Amount.to_string(a1)             # "100.50"
Amount.to_string(a1, :with_sign) # "+100.50"
```

### 2.2 Date

```
Date = ISO 8601 date
Date.today() = 2024-01-15
Date.parse("2024-01-15") = 2024-01-15
```

### 2.3 Account Path

```
# Account paths using hierarchical names
AccountPath = String with " : " delimiter
AccountPath.parse("Vermögen : Bank : Girokonto") = valid
AccountPath.parent("Vermögen : Bank : Girokonto") = "Vermögen : Bank"
AccountPath.name("Vermögen : Bank : Girokonto") = "Girokonto"
```

## 3. Account Definition DSL

### 3.1 Individual Account Creation

```
# Basic account definition
define_account "Vermögen : Bank : Girokonto" do
  name: "Girokonto"
  description: "Main business checking account"
  active: true
end

define_account "Ausgaben : Büro : Miete" do
  name: "Büro Miete"
  description: "Monthly office rent"
  active: true
end
```

### 3.2 Bulk Account Definition

```
# Hierarchical account structure using string-based naming
define_accounts do
  # Using hierarchical naming with colon separators
  group "Vermögen" do  # Assets
    account "Vermögen : Bargeld" with description: "Cash on hand"
    account "Vermögen : Kasse" with description: "Petty cash fund"
    group "Vermögen : Bank" do  # Bank accounts
      account "Vermögen : Bank : Girokonto" with description: "Main account"
      account "Vermögen : Bank : Sparkonto" with description: "Reserve funds"
    end
  end

  group "Vermögen : Anlagen" do  # Fixed assets
    account "Vermögen : Anlagen : Ausstattung" with description: "Office equipment"
    account "Vermögen : Anlagen : Möbel" with description: "Office furniture"
  end

  group "Verbindlichkeiten" do  # Liabilities
    account "Verbindlichkeiten : Lieferanten" with description: "Trade creditors"
    account "Verbindlichkeiten : Kreditkarten" with description: "Credit card liabilities"
  end

  group "Ausgaben : Betrieb" do  # Operating expenses
    account "Ausgaben : Betrieb : Miete" with description: "Office rent"
    account "Ausgaben : Betrieb : Nebenkosten" with description: "Electricity, water, etc."
  end
end
```

## 5. Entry DSL

## 4. Entry DSL

### 4.1 Basic Entry Syntax

```
# Simple entry syntax - using hierarchical account names
entry do
  date: 2024-01-15
  description: "Purchase office supplies"

  position "Ausgaben : Büro : Material", Amount.new(50.00)
  position "Vermögen : Bank : Girokonto", Amount.new(-50.00)
end

# Or with implicit conversion
entry do
  date: 2024-01-15
  description: "Purchase office supplies"

  position "Ausgaben : Büro : Material", 50.00
  position "Vermögen : Bank : Girokonto", -50.00
end
```

### 4.2 Multi-Position Entries

```
# Multi-position entry
entry do
  date: 2024-01-20
  description: "Client payment with fees"

  position "Vermögen : Bank : Girokonto", +970.00
  position "Ausgaben : Bank : Gebühren", +30.00
  position "Vermögen : Forderungen", -1000.00
end
```

### 4.3 Tax-Relevant Positions

### 4.3 Tax Relevance Tagging

```
# Tax relevance tagging
entry do
  date: 2024-02-01
  description: "Craftsman invoice - renovation"

  position "Ausgaben : Renovierung : Arbeit", +800.00 do
    tax_relevant: true
    memo: "Deductible craftsman services"
  end

  position "Ausgaben : Renovierung : Material", +200.00 do
    tax_relevant: false
    memo: "Non-deductible materials"
  end

  position "Vermögen : Bank : Girokonto", -1000.00
end
```

## 6. Entry Templates DSL

### 5.1 Template Versioning

```
# Templates are immutable - new versions must be created for changes
template "Monthly Rent", version: 1 do
  default_total: 1500.00
  validate_accounts: true

  position "Ausgaben : Büro : Miete", +1500.00
  position "Vermögen : Bank : Girokonto", -1500.00
end

# Creating a new version when rent changes
template "Monthly Rent", version: 2 do
  default_total: 1600.00  # Rent increased
  validate_accounts: true

  position "Ausgaben : Büro : Miete", +1600.00
  position "Vermögen : Bank : Girokonto", -1600.00
end
```

### 5.2 Fixed Amount Template

```
# Fixed amount template with explicit version
template "Office Rent", version: 1 do
  default_total: 1500.00
  validate_accounts: true

  position "Ausgaben : Büro : Miete", +1500.00
  position "Vermögen : Bank : Girokonto", -1500.00
end
```

### 5.3 Variable Amount Template

```
# Template with parameter and version
template "Office Supplies Purchase", version: 1 do
  parameter :amount  # Can be Amount or numeric
  validate_accounts: true

  position "Ausgaben : Büro : Material", +amount
  position "Vermögen : Bank : Girokonto", -amount
end
```

### 5.4 Fraction-Based Template (Standard Approach)

```
# Template with fractions (percentage-based distribution)
template "Monthly Rent with Utilities", version: 1 do
  parameter :total_amount  # Amount type
  default_total: 2000.00
  validate_accounts: true

  # Using fractions as the standard approach
  position "Ausgaben : Büro : Miete", fraction: 0.80
  position "Ausgaben : Büro : Nebenkosten", fraction: 0.15
  position "Ausgaben : Büro : Wartung", fraction: 0.05
  position "Vermögen : Bank : Girokonto", fraction: -1.00
end
```

### 5.5 Complex Template with Distribution

```
# Template with automatic distribution
template "Split Invoice Three Ways", version: 1 do
  parameter :amount
  parameter :account_from
  validate_accounts: true

  # Automatic distribution using fractions
  position "Ausgaben : Partner : A", fraction: 1/3
  position "Ausgaben : Partner : B", fraction: 1/3
  position "Ausgaben : Partner : C", fraction: 1/3
  position account_from, fraction: -1.00
end
```

### 5.6 Using Templates

```
# Fixed template - uses latest version by default
apply_template "Monthly Rent" do
  date: 2024-02-01
  description: "February rent payment"
end

# Using specific version
apply_template "Monthly Rent", version: 1 do
  date: 2024-01-01
  description: "January rent payment (old rate)"
end

# Variable template with latest version
apply_template "Office Supplies Purchase" do
  date: 2024-02-05
  description: "Printer paper and toner"
  amount: 125.50
end

# Complex template
# Applying template with all parameters
apply_template "Split Invoice Three Ways" do
  date: 2024-02-10
  description: "Shared consulting expense"
  amount: 1000.00
  account_from: "Vermögen : Bank : Girokonto"
end
```

## 6. Canonical Examples

### 6.1 Salary Entry

```
# Monthly salary payment
entry do
  date: 2024-02-28
  description: "Gehalt Februar 2024"

  position "Einnahmen : Arbeit : Tideland", -3500.00
  position "Vermögen : Bank : Girokonto", +3500.00
end
```

### 6.2 Grocery Shopping

```
# Grocery purchase
entry do
  date: 2024-02-15
  description: "Einkauf Supermarkt"

  position "Ausgaben : Lebensmittel", +87.43
  position "Vermögen : Bargeld", -87.43
end
```

### 6.3 Rent Payment

```
# Monthly rent
entry do
  date: 2024-02-01
  description: "Miete Februar"

  position "Ausgaben : Wohnung : Miete", +1200.00
  position "Vermögen : Bank : Girokonto", -1200.00
end
```

### 6.4 Internal Transfer

```
# Transfer between accounts
entry do
  date: 2024-02-10
  description: "Überweisung Sparkonto"

  position "Vermögen : Bank : Sparkonto", +500.00
  position "Vermögen : Bank : Girokonto", -500.00
end
```

### 6.5 Loan Payment

```
# Loan payment with interest
entry do
  date: 2024-02-15
  description: "Kredittilgung"

  position "Ausgaben : Kredit : Tilgung", +400.00
  position "Ausgaben : Kredit : Zinsen", +50.00
  position "Vermögen : Bank : Girokonto", -450.00
end
```

### 6.6 Tax Payment

```
# Quarterly tax payment
entry do
  date: 2024-03-31
  description: "Umsatzsteuervorauszahlung Q1/2024"
  tax_relevant: true

  position "Ausgaben : Steuern : Umsatzsteuer", +2500.00
  position "Vermögen : Bank : Girokonto", -2500.00
end
```

## 7. Query DSL

### 7.1 Account Balance Queries

```
# Single account balance
balance_of "Vermögen : Bank : Girokonto"
=> 12,500.00

# Multiple accounts by hierarchy
balance_of accounts starting_with "Vermögen : Bank"
=> {"Vermögen : Bank : Girokonto" => 12,500.00,
    "Vermögen : Bank : Sparkonto" => 25,000.00}

# Balance at specific date
balance_of "Vermögen : Bank : Girokonto" at: 2024-01-31
=> 8,200.00
```

### 7.2 Report Generation

### 6.2 Entry Queries

```
# All entries for an account
entries_for "Vermögen : Bank : Girokonto" do
  from: 2024-01-01
  to: 2024-01-31
end

# Entries matching criteria
entries where do
  account: starts_with("Ausgaben")  # All expense accounts
  amount: greater_than(100.00)
  date: in_month(2024, 1)
end
```

### 6.3 Report Queries

```
# Balance sheet
balance_sheet at: 2024-01-31

# Trial balance
trial_balance at: 2024-01-31

# Account activity
activity_report for: "Vermögen : Bank : Girokonto" do
  from: 2024-01-01
  to: 2024-01-31
  include_running_balance: true
end
```

## 8. Validation DSL

### 7.1 Entry Validation Rules

```
validate entry do
  must sum_to_zero
  must have_at_least_two_positions
  must have_valid_accounts
  must have_date
  positions must have_non_zero_amounts
end
```

### 8.2 Template Validation Rules

```
validate template do
  must have_valid_accounts
  must have_at_least_two_positions
  fractions must sum_to_zero
  when has_default_total do
    must be_positive
  end
end
```

### 8.3 Account Validation Rules

```
# Account validation
validate account do
  must have_unique_code
  must have_valid_parent
  must have_name
end
```

### 8.4 Custom Validation Rules

```
# Entry validation with conditions
validate entry do
  when description: contains("Tax") do
    at_least_one position must have tax_relevant: true
  end

  when any_position_for account: matching("12*") do  # Bank accounts
    must have description: not_empty
  end
end
```

## 9. User Permission DSL

### 8.1 Role Definitions (Hardcoded)

```
# Roles are hardcoded in the system
define_role :admin do
  can :create, :update, :delete, :post on: Entry
  can :create, :update, :delete on: Account
  can :create, :update, :delete on: User
  can :create, :update, :delete on: Template
  can :view on: all
  can :change_password for: all_users
end

define_role :bookkeeper do
  can :create, :update on: Entry
  can :post on: Entry where created_by: current_user
  can :view on: [Entry, Account, Report, Template]
  can :change_password for: current_user
  cannot :delete on: any
end

define_role :viewer do
  can :view on: [Entry, Account, Report]
  can :change_password for: current_user
  cannot :create, :update, :delete, :post on: any
end

# Hardcoded admin user
system_user "admin" do
  role: :admin
  password_hash: configured_from_toml
  must_change_password: on_first_login
end
```

## 10. Import/Export DSL

### 9.1 CSV Import Mapping

```
import_csv "entries.csv" do
  map column: "Date" to: :date with: date_parser("dd.mm.yyyy")
  map column: "Description" to: :description
  map column: "Account" to: :account with: account_lookup
  map column: "Amount" to: :amount with: amount_parser
  map column: "Type" to: :type  # "debit" or "credit"

  create_entry for_each_row do |row|
    date: row.date
    description: row.description

    # Convert to signed amount based on type
    signed_amount = row.type == "debit" ? row.amount : -row.amount

    position row.account, signed_amount
    position "1200", -signed_amount  # Bank - Checking
  end
end
```

### 9.2 Backup/Restore

```
# Backup
backup to: "ledger_backup_2024_02_01.sqlite" do
  include: all_data
  compress: true
end

# Restore
restore from: "ledger_backup_2024_02_01.sqlite" do
  verify_integrity: true
  merge_strategy: :replace_all
end
```

## 11. DSL Benefits

This DSL provides:

1. **Readability**: Business logic expressed in domain terms
2. **Safety**: Type checking and validation built-in
3. **Composability**: Templates and queries can be combined
4. **Extensibility**: New operations can be added without changing core syntax
5. **Testability**: DSL operations can be easily tested in isolation

## 12. Translation to Elixir

The DSL maps naturally to Elixir constructs:

- `define_account` → Ecto schema definitions
- `entry do` → Entry context functions
- `template` → Template module with apply functions
- `validate` → Ecto changesets and custom validations
- `balance_of` → Repo queries with aggregations
- Permissions → Authorization library (e.g., Canada or custom)

This DSL serves as the conceptual model that will guide the Elixir implementation.
