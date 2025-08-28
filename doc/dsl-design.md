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
# Account paths using codes and names
AccountPath = String with " : " delimiter
AccountPath.parse("1000 : 1200 : Checking") = valid
AccountPath.parent("1000 : 1200 : Checking") = "1000 : 1200"
AccountPath.name("1000 : 1200 : Checking") = "Checking"
```

## 4. Account Definition DSL

### 3.1 Basic Account Definition

```
# Basic account definition
define_account "1200" do
  name: "Bank - Checking"
  description: "Main business checking account"
  active: true
end

define_account "4200" do
  name: "Office Rent"
  description: "Monthly office rent"
  active: true
end
```

### 3.2 Bulk Account Definition

```
# Hierarchical account structure using code ranges
define_accounts do
  # Using SKR03-style numbering
  group "1000-1999" do  # Bank accounts and cash
    account "1000" with name: "Cash", description: "Cash on hand"
    account "1001" with name: "Petty Cash", description: "Petty cash fund"
    group "1200-1299" do  # Bank accounts
      account "1200" with name: "Bank - Checking", description: "Main account"
      account "1210" with name: "Bank - Savings", description: "Reserve funds"
    end
  end

  group "0400-0999" do  # Fixed assets
    account "0620" with name: "Equipment", description: "Office equipment"
    account "0650" with name: "Furniture", description: "Office furniture"
  end

  group "3000-3999" do  # Liabilities
    account "3000" with name: "Accounts Payable", description: "Trade creditors"
    account "3100" with name: "Credit Card Payable", description: "Credit card liabilities"
  end

  group "4000-4999" do  # Operating expenses
    account "4200" with name: "Rent", description: "Office rent"
    account "4300" with name: "Utilities", description: "Electricity, water, etc."
  end
end
```

## 5. Transaction DSL

### 4.1 Simple Transaction

```
# Simple double-entry syntax - using account codes
transaction do
  date: 2024-01-15
  description: "Purchase office supplies"

  debit  "4100", Amount.new(50.00)  # Office Supplies
  credit "1200", Amount.new(50.00)  # Bank - Checking
end

# Or with implicit conversion
transaction do
  date: 2024-01-15
  description: "Purchase office supplies"

  debit  "4100", 50.00  # Office Supplies
  credit "1200", 50.00  # Bank - Checking
end
```

### 4.2 Using Position Syntax

```
# Position-based syntax (positive/negative amounts)
transaction do
  date: 2024-01-15
  description: "Purchase office supplies"

  position "4100", +50.00  # Office Supplies
  position "1200", -50.00  # Bank - Checking
end
```

### 4.3 Multi-Position Transaction

```
# Multi-position transaction
transaction do
  date: 2024-01-20
  description: "Client payment with fees"

  position "1200", +970.00   # Bank - Checking
  position "4900", +30.00    # Bank Fees
  position "1400", -1000.00  # Accounts Receivable
end
```

### 4.4 Tax-Relevant Positions

```
# Tax relevance tagging
transaction do
  date: 2024-02-01
  description: "Craftsman invoice - renovation"

  position "4500", +800.00 do  # Renovation Labor
    tax_relevant: true
    memo: "Deductible craftsman services"
  end

  position "4510", +200.00 do  # Renovation Materials
    tax_relevant: false
    memo: "Non-deductible materials"
  end

  position "1200", -1000.00  # Bank - Checking
end
```

## 6. Transaction Templates DSL

### 5.1 Fixed Amount Template

```
# Fixed amount template
template "Monthly Rent" do
  default_total: 1500.00
  validate_accounts: true

  position "4200", +1500.00  # Office Rent
  position "1200", -1500.00  # Bank - Checking
end
```

### 5.2 Variable Amount Template

```
# Template with parameter
template "Office Supplies Purchase" do
  parameter :amount  # Can be Amount or numeric
  validate_accounts: true

  position "4100", +amount  # Office Supplies
  position "1200", -amount  # Bank - Checking
end
```

### 5.3 Fraction-Based Template (Standard Approach)

```
# Template with fractions (percentage-based distribution)
template "Monthly Rent with Utilities" do
  parameter :total_amount  # Amount type
  default_total: 2000.00
  validate_accounts: true

  # Using fractions as the standard approach
  position "4200", fraction: 0.80   # Office Rent
  position "4300", fraction: 0.15   # Utilities
  position "4400", fraction: 0.05   # Maintenance
  position "1200", fraction: -1.00  # Bank - Checking
end
```

### 5.4 Complex Template with Distribution

```
# Template with automatic distribution
template "Split Invoice Three Ways" do
  parameter :amount
  parameter :account_from
  validate_accounts: true

  # Automatic distribution using fractions
  position "4801", fraction: 1/3  # Partner A Share
  position "4802", fraction: 1/3  # Partner B Share
  position "4803", fraction: 1/3  # Partner C Share
  position account_from, fraction: -1.00
end
```

### 5.5 Using Templates

```
# Fixed template
apply_template "Monthly Rent" do
  date: 2024-02-01
  description: "February rent payment"
end

# Variable template
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
  account_from: "1200"  # Bank - Checking
end
```

## 7. Query DSL

### 6.1 Account Balance Queries

```
# Single account balance
balance_of "1200"  # Bank - Checking
=> 12,500.00

# Multiple accounts by code range
balance_of accounts matching "12*"
=> {"1200" => 12,500.00,  # Bank - Checking
    "1210" => 25,000.00}  # Bank - Savings

# Balance at specific date
balance_of "1200" at: 2024-01-31
=> 8,200.00
```

### 6.2 Transaction Queries

```
# All transactions for an account
transactions_for "1200" do  # Bank - Checking
  from: 2024-01-01
  to: 2024-01-31
end

# Transactions matching criteria
transactions where do
  account: "4*"  # All expense accounts
  amount: greater_than(100.00)
  date: in_month(2024, 1)
end
```

### 6.3 Report Queries

```
# Balance sheet (using account code ranges)
balance_sheet at: 2024-01-31

# Trial balance
trial_balance at: 2024-01-31

# Account activity
activity_report for: "1200" do  # Bank - Checking
  from: 2024-01-01
  to: 2024-01-31
  include_running_balance: true
end
```

## 8. Validation DSL

### 7.1 Transaction Validation Rules

```
validate transaction do
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
# Transaction validation with conditions
validate transaction do
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
  can :create, :update, :delete, :post on: Transaction
  can :create, :update, :delete on: Account
  can :create, :update, :delete on: User
  can :create, :update, :delete on: Template
  can :view on: all
  can :change_password for: all_users
end

define_role :bookkeeper do
  can :create, :update on: Transaction
  can :post on: Transaction where created_by: current_user
  can :view on: [Transaction, Account, Report, Template]
  can :change_password for: current_user
  cannot :delete on: any
end

define_role :viewer do
  can :view on: [Transaction, Account, Report]
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
import_csv "transactions.csv" do
  map column: "Date" to: :date with: date_parser("dd.mm.yyyy")
  map column: "Description" to: :description
  map column: "Account" to: :account with: account_lookup
  map column: "Debit" to: :debit_amount with: amount_parser
  map column: "Credit" to: :credit_amount with: amount_parser

  create_transaction for_each_row do |row|
    date: row.date
    description: row.description

    if row.debit_amount > 0
      position row.account, +row.debit_amount
      position "Assets : Bank : Checking", -row.debit_amount
    else
      position row.account, -row.credit_amount
      position "Assets : Bank : Checking", +row.credit_amount
    end
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
- `transaction do` → Transaction context functions
- `template` → Template module with apply functions
- `validate` → Ecto changesets and custom validations
- `balance_of` → Repo queries with aggregations
- Permissions → Authorization library (e.g., Canada or custom)

This DSL serves as the conceptual model that will guide the Elixir implementation.
