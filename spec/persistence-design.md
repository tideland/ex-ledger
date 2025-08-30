# Tideland Ledger - Persistence Design

## Table of Contents

1. [Domain-Specific Language (DSL) for Data Model](#1-domain-specific-language-dsl-for-data-model)
2. [SQLite SQL Statements](#2-sqlite-sql-statements)
3. [Ecto Implementation](#3-ecto-implementation)

---

## 1. Domain-Specific Language (DSL) for Data Model

This section defines the data model using a declarative DSL that describes tables, fields, types, constraints, and relationships.

### 1.1 DSL Syntax Definition

```
TABLE table_name {
  FIELD field_name : type [constraints]
  ...
  CONSTRAINT constraint_name constraint_definition
  INDEX index_name ON (fields...)
}

RELATION relation_name {
  FROM table.field
  TO table.field
  TYPE one_to_one | one_to_many | many_to_many
  [CASCADE delete | restrict | set_null]
}
```

### 1.2 Base Types

- `ID`: Auto-incrementing integer primary key
- `UUID`: Universally unique identifier
- `STRING(n)`: Variable-length string with max length n
- `TEXT`: Unlimited text
- `INTEGER`: 64-bit integer
- `DECIMAL(p,s)`: Decimal with precision p and scale s
- `BOOLEAN`: True/false value
- `DATE`: Date without time
- `DATETIME`: Date with time
- `TIMESTAMP`: Unix timestamp with timezone
- `ENUM[values...]`: Enumerated type with specific values
- `JSON`: JSON data (stored as TEXT in SQLite)

### 1.3 Data Model Definition

```dsl
// User management (delegated to auth service, but we keep reference)
TABLE users {
  FIELD id : ID
  FIELD external_id : UUID [NOT NULL, UNIQUE]  // ID from auth service
  FIELD username : STRING(50) [NOT NULL, UNIQUE]
  FIELD role : ENUM[admin, bookkeeper, viewer] [NOT NULL, DEFAULT viewer]
  FIELD created_at : TIMESTAMP [NOT NULL, DEFAULT NOW]
  FIELD updated_at : TIMESTAMP [NOT NULL, DEFAULT NOW]

  INDEX idx_users_external_id ON (external_id)
  INDEX idx_users_username ON (username)
}

// Chart of Accounts
TABLE accounts {
  FIELD id : ID
  FIELD code : STRING(20) [NOT NULL, UNIQUE]
  FIELD name : STRING(100) [NOT NULL]
  FIELD parent_id : INTEGER [NULL]  // Self-reference for account hierarchy
  FIELD description : TEXT [NULL]
  FIELD active : BOOLEAN [NOT NULL, DEFAULT true]
  FIELD created_at : TIMESTAMP [NOT NULL, DEFAULT NOW]
  FIELD updated_at : TIMESTAMP [NOT NULL, DEFAULT NOW]
  FIELD created_by : INTEGER [NOT NULL]

  CONSTRAINT fk_accounts_parent FOREIGN KEY (parent_id) REFERENCES accounts(id)
  CONSTRAINT fk_accounts_created_by FOREIGN KEY (created_by) REFERENCES users(id)

  INDEX idx_accounts_code ON (code)
  INDEX idx_accounts_parent ON (parent_id)
}

// Transactions (Journal Entries)
TABLE transactions {
  FIELD id : ID
  FIELD transaction_date : DATE [NOT NULL]
  FIELD description : STRING(200) [NOT NULL]
  FIELD reference_number : STRING(50) [NULL]
  FIELD status : ENUM[draft, posted, void] [NOT NULL, DEFAULT draft]
  FIELD posted_at : TIMESTAMP [NULL]
  FIELD voided_at : TIMESTAMP [NULL]
  FIELD created_at : TIMESTAMP [NOT NULL, DEFAULT NOW]
  FIELD updated_at : TIMESTAMP [NOT NULL, DEFAULT NOW]
  FIELD created_by : INTEGER [NOT NULL]
  FIELD posted_by : INTEGER [NULL]
  FIELD voided_by : INTEGER [NULL]

  CONSTRAINT fk_transactions_created_by FOREIGN KEY (created_by) REFERENCES users(id)
  CONSTRAINT fk_transactions_posted_by FOREIGN KEY (posted_by) REFERENCES users(id)
  CONSTRAINT fk_transactions_voided_by FOREIGN KEY (voided_by) REFERENCES users(id)

  INDEX idx_transactions_date ON (transaction_date)
  INDEX idx_transactions_status ON (status)
  INDEX idx_transactions_reference ON (reference_number)
}

// Transaction Lines (Double-entry lines)
TABLE transaction_lines {
  FIELD id : ID
  FIELD transaction_id : INTEGER [NOT NULL]
  FIELD account_id : INTEGER [NOT NULL]
  FIELD description : STRING(200) [NULL]
  FIELD amount : DECIMAL(15,2) [NOT NULL]  // Positive = Debit, Negative = Credit
  FIELD tax_relevant : BOOLEAN [NOT NULL, DEFAULT false]
  FIELD position : INTEGER [NOT NULL]  // Order within transaction
  FIELD created_at : TIMESTAMP [NOT NULL, DEFAULT NOW]
  FIELD updated_at : TIMESTAMP [NOT NULL, DEFAULT NOW]

  CONSTRAINT fk_lines_transaction FOREIGN KEY (transaction_id) REFERENCES transactions(id)
  CONSTRAINT fk_lines_account FOREIGN KEY (account_id) REFERENCES accounts(id)
  CONSTRAINT chk_lines_amount CHECK (amount != 0)

  INDEX idx_lines_transaction ON (transaction_id)
  INDEX idx_lines_account ON (account_id)
  INDEX idx_lines_tax_relevant ON (tax_relevant)
}

// Transaction Templates
TABLE templates {
  FIELD id : ID
  FIELD code : STRING(20) [NOT NULL, UNIQUE]
  FIELD name : STRING(100) [NOT NULL]
  FIELD description : TEXT [NULL]
  FIELD default_total : DECIMAL(15,2) [NULL]
  FIELD active : BOOLEAN [NOT NULL, DEFAULT true]
  FIELD created_at : TIMESTAMP [NOT NULL, DEFAULT NOW]
  FIELD updated_at : TIMESTAMP [NOT NULL, DEFAULT NOW]
  FIELD created_by : INTEGER [NOT NULL]

  CONSTRAINT fk_templates_created_by FOREIGN KEY (created_by) REFERENCES users(id)

  INDEX idx_templates_code ON (code)
  INDEX idx_templates_active ON (active)
}

// Template Lines
TABLE template_lines {
  FIELD id : ID
  FIELD template_id : INTEGER [NOT NULL]
  FIELD account_id : INTEGER [NOT NULL]
  FIELD description : STRING(200) [NULL]
  FIELD line_type : ENUM[debit, credit] [NOT NULL]
  FIELD amount_type : ENUM[fixed, percentage] [NOT NULL]
  FIELD amount_value : DECIMAL(15,4) [NOT NULL]  // Value or percentage
  FIELD tax_relevant : BOOLEAN [NOT NULL, DEFAULT false]
  FIELD position : INTEGER [NOT NULL]

  CONSTRAINT fk_template_lines_template FOREIGN KEY (template_id) REFERENCES templates(id)
  CONSTRAINT fk_template_lines_account FOREIGN KEY (account_id) REFERENCES accounts(id)
  CONSTRAINT chk_percentage_range CHECK (
    amount_type != 'percentage' OR (amount_value >= 0 AND amount_value <= 100)
  )

  INDEX idx_template_lines_template ON (template_id)
  INDEX idx_template_lines_account ON (account_id)
}

// Audit Log
TABLE audit_log {
  FIELD id : ID
  FIELD table_name : STRING(50) [NOT NULL]
  FIELD record_id : INTEGER [NOT NULL]
  FIELD action : ENUM[insert, update, delete] [NOT NULL]
  FIELD changed_data : JSON [NOT NULL]
  FIELD user_id : INTEGER [NOT NULL]
  FIELD timestamp : TIMESTAMP [NOT NULL, DEFAULT NOW]

  CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES users(id)

  INDEX idx_audit_table_record ON (table_name, record_id)
  INDEX idx_audit_timestamp ON (timestamp)
  INDEX idx_audit_user ON (user_id)
}

// Account Balances (Materialized view for performance)
TABLE account_balances {
  FIELD id : ID
  FIELD account_id : INTEGER [NOT NULL]
  FIELD period_year : INTEGER [NOT NULL]
  FIELD period_month : INTEGER [NOT NULL]
  FIELD debit_total : DECIMAL(15,2) [NOT NULL, DEFAULT 0.00]
  FIELD credit_total : DECIMAL(15,2) [NOT NULL, DEFAULT 0.00]
  FIELD transaction_count : INTEGER [NOT NULL, DEFAULT 0]
  FIELD last_updated : TIMESTAMP [NOT NULL, DEFAULT NOW]

  CONSTRAINT fk_balances_account FOREIGN KEY (account_id) REFERENCES accounts(id)
  CONSTRAINT uk_balances_period UNIQUE (account_id, period_year, period_month)

  INDEX idx_balances_account ON (account_id)
  INDEX idx_balances_period ON (period_year, period_month)
}

// Relations
RELATION users_created_accounts {
  FROM users.id
  TO accounts.created_by
  TYPE one_to_many
  CASCADE restrict
}

RELATION accounts_hierarchy {
  FROM accounts.id
  TO accounts.parent_id
  TYPE one_to_many
  CASCADE restrict
}

RELATION transactions_have_lines {
  FROM transactions.id
  TO transaction_lines.transaction_id
  TYPE one_to_many
  CASCADE delete
}

RELATION accounts_have_lines {
  FROM accounts.id
  TO transaction_lines.account_id
  TYPE one_to_many
  CASCADE restrict
}

RELATION templates_have_lines {
  FROM templates.id
  TO template_lines.template_id
  TYPE one_to_many
  CASCADE delete
}
```

### 1.4 Business Rules in DSL

```dsl
RULE balanced_transaction {
  FOR EACH transaction
  WHERE status = 'posted'
  ASSERT SUM(transaction_lines.amount) = 0
}

RULE valid_account_hierarchy {
  FOR EACH account
  WHERE parent_id IS NOT NULL
  ASSERT parent exists
}

RULE no_void_modifications {
  FOR EACH transaction
  WHERE status = 'void'
  DENY UPDATE EXCEPT (voided_at, voided_by)
}

RULE minimum_transaction_lines {
  FOR EACH transaction
  ASSERT COUNT(transaction_lines) >= 2
}
```

---

## 2. SQLite SQL Statements

### 2.1 Table Creation

```sql
-- Enable foreign key support in SQLite
PRAGMA foreign_keys = ON;

-- Users table
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    external_id TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('admin', 'bookkeeper', 'viewer')),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_external_id ON users(external_id);
CREATE INDEX idx_users_username ON users(username);

-- Accounts table
CREATE TABLE accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    parent_id INTEGER,
    description TEXT,
    active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER NOT NULL,
    FOREIGN KEY (parent_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT
);

CREATE INDEX idx_accounts_code ON accounts(code);
CREATE INDEX idx_accounts_parent ON accounts(parent_id);

-- Transactions table
CREATE TABLE transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_date DATE NOT NULL,
    description TEXT NOT NULL,
    reference_number TEXT,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'posted', 'void')),
    posted_at DATETIME,
    voided_at DATETIME,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER NOT NULL,
    posted_by INTEGER,
    voided_by INTEGER,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT,
    FOREIGN KEY (posted_by) REFERENCES users(id) ON DELETE RESTRICT,
    FOREIGN KEY (voided_by) REFERENCES users(id) ON DELETE RESTRICT
);

CREATE INDEX idx_transactions_date ON transactions(transaction_date);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_reference ON transactions(reference_number);

-- Transaction lines table
CREATE TABLE transaction_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id INTEGER NOT NULL,
    account_id INTEGER NOT NULL,
    description TEXT,
    amount DECIMAL(15,2) NOT NULL,
    tax_relevant INTEGER NOT NULL DEFAULT 0,
    position INTEGER NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK (amount != 0)
);

CREATE INDEX idx_lines_transaction ON transaction_lines(transaction_id);
CREATE INDEX idx_lines_account ON transaction_lines(account_id);
CREATE INDEX idx_lines_tax_relevant ON transaction_lines(tax_relevant);

-- Templates table
CREATE TABLE templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    default_total DECIMAL(15,2),
    active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER NOT NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE RESTRICT
);

CREATE INDEX idx_templates_code ON templates(code);
CREATE INDEX idx_templates_active ON templates(active);

-- Template lines table
CREATE TABLE template_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    template_id INTEGER NOT NULL,
    account_id INTEGER NOT NULL,
    description TEXT,
    line_type TEXT NOT NULL CHECK (line_type IN ('debit', 'credit')),
    amount_type TEXT NOT NULL CHECK (amount_type IN ('fixed', 'percentage')),
    amount_value DECIMAL(15,4) NOT NULL,
    tax_relevant INTEGER NOT NULL DEFAULT 0,
    position INTEGER NOT NULL,
    FOREIGN KEY (template_id) REFERENCES templates(id) ON DELETE CASCADE,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    CHECK (amount_type != 'percentage' OR (amount_value >= 0 AND amount_value <= 100))
);

CREATE INDEX idx_template_lines_template ON template_lines(template_id);
CREATE INDEX idx_template_lines_account ON template_lines(account_id);

-- Audit log table
CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    table_name TEXT NOT NULL,
    record_id INTEGER NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('insert', 'update', 'delete')),
    changed_data TEXT NOT NULL, -- JSON stored as TEXT
    user_id INTEGER NOT NULL,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT
);

CREATE INDEX idx_audit_table_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX idx_audit_user ON audit_log(user_id);

-- Account balances table
CREATE TABLE account_balances (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL,
    period_year INTEGER NOT NULL,
    period_month INTEGER NOT NULL,
    debit_total DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    credit_total DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    transaction_count INTEGER NOT NULL DEFAULT 0,
    last_updated DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE RESTRICT,
    UNIQUE (account_id, period_year, period_month)
);

CREATE INDEX idx_balances_account ON account_balances(account_id);
CREATE INDEX idx_balances_period ON account_balances(period_year, period_month);
```

### 2.2 Triggers for Data Integrity

```sql
-- Update timestamp triggers
CREATE TRIGGER update_users_timestamp
AFTER UPDATE ON users
BEGIN
    UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER update_accounts_timestamp
AFTER UPDATE ON accounts
BEGIN
    UPDATE accounts SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER update_transactions_timestamp
AFTER UPDATE ON transactions
BEGIN
    UPDATE transactions SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER update_transaction_lines_timestamp
AFTER UPDATE ON transaction_lines
BEGIN
    UPDATE transaction_lines SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

CREATE TRIGGER update_templates_timestamp
AFTER UPDATE ON templates
BEGIN
    UPDATE templates SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Audit triggers
CREATE TRIGGER audit_accounts_insert
AFTER INSERT ON accounts
BEGIN
    INSERT INTO audit_log (table_name, record_id, action, changed_data, user_id)
    VALUES ('accounts', NEW.id, 'insert',
            json_object('code', NEW.code, 'name', NEW.name, 'type', NEW.type),
            NEW.created_by);
END;

CREATE TRIGGER audit_transactions_update
AFTER UPDATE ON transactions
WHEN NEW.status != OLD.status
BEGIN
    INSERT INTO audit_log (table_name, record_id, action, changed_data, user_id)
    VALUES ('transactions', NEW.id, 'update',
            json_object('old_status', OLD.status, 'new_status', NEW.status),
            COALESCE(NEW.posted_by, NEW.voided_by, NEW.created_by));
END;

-- Balance check trigger
CREATE TRIGGER check_transaction_balance
BEFORE UPDATE ON transactions
WHEN NEW.status = 'posted' AND OLD.status = 'draft'
BEGIN
    SELECT CASE
        WHEN (SELECT SUM(amount)
              FROM transaction_lines
              WHERE transaction_id = NEW.id) != 0
        THEN RAISE(ABORT, 'Transaction is not balanced')
    END;
END;
```

### 2.3 Views for Reporting

```sql
-- Account hierarchy view
CREATE VIEW v_account_hierarchy AS
WITH RECURSIVE account_tree AS (
    SELECT a.*, 0 as level, a.code as path
    FROM accounts a
    WHERE a.parent_id IS NULL

    UNION ALL

    SELECT a.*, at.level + 1, at.path || '.' || a.code
    FROM accounts a
    INNER JOIN account_tree at ON a.parent_id = at.id
)
SELECT * FROM account_tree;

-- Transaction details view
CREATE VIEW v_transaction_details AS
SELECT
    t.id,
    t.transaction_date,
    t.description,
    t.reference_number,
    t.status,
    tl.position,
    tl.account_id,
    a.code as account_code,
    a.name as account_name,
    tl.description as line_description,
    tl.amount,
    CASE WHEN tl.amount > 0 THEN tl.amount ELSE 0 END as debit_amount,
    CASE WHEN tl.amount < 0 THEN ABS(tl.amount) ELSE 0 END as credit_amount,
    tl.tax_relevant,
    u.username as created_by_username
FROM transactions t
INNER JOIN transaction_lines tl ON t.id = tl.transaction_id
INNER JOIN accounts a ON tl.account_id = a.id
INNER JOIN users u ON t.created_by = u.id
ORDER BY t.transaction_date DESC, t.id, tl.position;

-- Current account balances view
CREATE VIEW v_account_balances AS
SELECT
    a.id,
    a.code,
    a.name,
    COALESCE(SUM(CASE WHEN tl.amount > 0 THEN tl.amount ELSE 0 END), 0) as total_debit,
    COALESCE(SUM(CASE WHEN tl.amount < 0 THEN ABS(tl.amount) ELSE 0 END), 0) as total_credit,
    COALESCE(SUM(tl.amount), 0) as balance
FROM accounts a
LEFT JOIN transaction_lines tl ON a.id = tl.account_id
LEFT JOIN transactions t ON tl.transaction_id = t.id AND t.status = 'posted'
GROUP BY a.id, a.code, a.name;
```

### 2.4 Common Queries

```sql
-- Get trial balance
SELECT
    code,
    name,
    SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as debit_total,
    SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as credit_total,
    SUM(amount) as balance
FROM v_transaction_details
WHERE status = 'posted'
GROUP BY account_id, code, name
ORDER BY code;

-- Get account statement
SELECT
    transaction_date,
    reference_number,
    description,
    amount,
    SUM(amount) OVER (ORDER BY transaction_date, id) as running_balance
FROM v_transaction_details
WHERE account_code = ? AND status = 'posted'
ORDER BY transaction_date, id;

-- Check for unbalanced transactions
SELECT
    id,
    transaction_date,
    description,
    SUM(CASE WHEN tl.amount > 0 THEN tl.amount ELSE 0 END) as total_debit,
    SUM(CASE WHEN tl.amount < 0 THEN ABS(tl.amount) ELSE 0 END) as total_credit,
    SUM(tl.amount) as imbalance
FROM transactions t
INNER JOIN transaction_lines tl ON t.id = tl.transaction_id
GROUP BY t.id, t.transaction_date, t.description
HAVING imbalance != 0;
```

---

## 3. Ecto Implementation

### 3.1 Schema Definitions

```elixir
# lib/ledger/accounts/user.ex
defmodule Ledger.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :external_id, Ecto.UUID
    field :username, :string
    field :role, Ecto.Enum, values: [:admin, :bookkeeper, :viewer], default: :viewer

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:external_id, :username, :role])
    |> validate_required([:external_id, :username, :role])
    |> unique_constraint(:external_id)
    |> unique_constraint(:username)
  end
end

# lib/ledger/accounts/account.ex
defmodule Ledger.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounts" do
    field :code, :string
    field :name, :string
    field :description, :string
    field :active, :boolean, default: true

    belongs_to :parent, __MODULE__
    belongs_to :created_by, Ledger.Accounts.User
    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :transaction_lines, Ledger.Transactions.TransactionLine

    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:code, :name, :description, :active, :parent_id, :created_by_id])
    |> validate_required([:code, :name, :created_by_id])
    |> validate_length(:code, max: 20)
    |> validate_length(:name, max: 100)
    |> unique_constraint(:code)
    |> foreign_key_constraint(:parent_id)
    |> foreign_key_constraint(:created_by_id)
  end
end

# lib/ledger/transactions/transaction.ex
defmodule Ledger.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :transaction_date, :date
    field :description, :string
    field :reference_number, :string
    field :status, Ecto.Enum, values: [:draft, :posted, :void], default: :draft
    field :posted_at, :utc_datetime
    field :voided_at, :utc_datetime

    belongs_to :created_by, Ledger.Accounts.User
    belongs_to :posted_by, Ledger.Accounts.User
    belongs_to :voided_by, Ledger.Accounts.User
    has_many :lines, Ledger.Transactions.TransactionLine

    timestamps()
  end

  @doc false
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [:transaction_date, :description, :reference_number, :status,
                    :posted_at, :voided_at, :created_by_id, :posted_by_id, :voided_by_id])
    |> validate_required([:transaction_date, :description, :created_by_id])
    |> validate_length(:description, max: 200)
    |> validate_length(:reference_number, max: 50)
    |> validate_status_transitions()
    |> cast_assoc(:lines, required: true)
    |> validate_balanced_transaction()
    |> validate_minimum_lines()
  end

  defp validate_status_transitions(changeset) do
    case {get_field(changeset, :status), get_change(changeset, :status)} do
      {_, nil} -> changeset
      {:draft, :posted} -> changeset
      {:draft, :void} -> add_error(changeset, :status, "cannot void draft transaction")
      {:posted, :void} -> changeset
      {:posted, :draft} -> add_error(changeset, :status, "cannot unpost transaction")
      {:void, _} -> add_error(changeset, :status, "cannot change void transaction")
      _ -> changeset
    end
  end

  defp validate_balanced_transaction(changeset) do
    case get_field(changeset, :status) do
      :posted ->
        lines = get_field(changeset, :lines) || []
        total = Enum.reduce(lines, Decimal.new(0), fn line, acc ->
          Decimal.add(line.amount || Decimal.new(0), acc)
        end)

        if Decimal.eq?(total, 0) do
          changeset
        else
          add_error(changeset, :lines, "transaction must balance to zero")
        end
      _ -> changeset
    end
  end

  defp validate_minimum_lines(changeset) do
    lines = get_field(changeset, :lines) || []
    if length(lines) >= 2 do
      changeset
    else
      add_error(changeset, :lines, "transaction must have at least 2 lines")
    end
  end
end

# lib/ledger/transactions/transaction_line.ex
defmodule Ledger.Transactions.TransactionLine do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transaction_lines" do
    field :description, :string
    field :amount, :decimal
    field :tax_relevant, :boolean, default: false
    field :position, :integer

    belongs_to :transaction, Ledger.Transactions.Transaction
    belongs_to :account, Ledger.Accounts.Account

    timestamps()
  end

  @doc false
  def changeset(line, attrs) do
    line
    |> cast(attrs, [:account_id, :description, :amount, :tax_relevant, :position])
    |> validate_required([:account_id, :amount, :position])
    |> validate_length(:description, max: 200)
    |> validate_number(:amount, not_equal_to: 0)
    |> foreign_key_constraint(:account_id)
  end
end

# lib/ledger/templates/template.ex
defmodule Ledger.Templates.Template do
  use Ecto.Schema
  import Ecto.Changeset

  schema "templates" do
    field :code, :string
    field :name, :string
    field :description, :string
    field :default_total, :decimal
    field :active, :boolean, default: true

    belongs_to :created_by, Ledger.Accounts.User
    has_many :lines, Ledger.Templates.TemplateLine

    timestamps()
  end

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:code, :name, :description, :default_total, :active, :created_by_id])
    |> validate_required([:code, :name, :created_by_id])
    |> validate_length(:code, max: 20)
    |> validate_length(:name, max: 100)
    |> unique_constraint(:code)
    |> cast_assoc(:lines)
  end
end

# lib/ledger/templates/template_line.ex
defmodule Ledger.Templates.TemplateLine do
  use Ecto.Schema
  import Ecto.Changeset

  schema "template_lines" do
    field :description, :string
    field :line_type, Ecto.Enum, values: [:debit, :credit]
    field :amount_type, Ecto.Enum, values: [:fixed, :percentage]
    field :amount_value, :decimal
    field :tax_relevant, :boolean, default: false
    field :position, :integer

    belongs_to :template, Ledger.Templates.Template
    belongs_to :account, Ledger.Accounts.Account
  end

  @doc false
  def changeset(line, attrs) do
    line
    |> cast(attrs, [:account_id, :description, :line_type, :amount_type,
                    :amount_value, :tax_relevant, :position])
    |> validate_required([:account_id, :line_type, :amount_type, :amount_value, :position])
    |> validate_length(:description, max: 200)
    |> validate_number(:amount_value, greater_than_or_equal_to: 0)
    |> validate_percentage_range()
    |> foreign_key_constraint(:account_id)
  end

  defp validate_percentage_range(changeset) do
    case get_field(changeset, :amount_type) do
      :percentage ->
        validate_number(changeset, :amount_value, less_than_or_equal_to: 100)
      _ ->
        changeset
    end
  end
end

# lib/ledger/audit/audit_log.ex
defmodule Ledger.Audit.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_log" do
    field :table_name, :string
    field :record_id, :integer
    field :action, Ecto.Enum, values: [:insert, :update, :delete]
    field :changed_data, :map
    field :timestamp, :utc_datetime

    belongs_to :user, Ledger.Accounts.User
  end

  @doc false
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [:table_name, :record_id, :action, :changed_data, :user_id])
    |> validate_required([:table_name, :record_id, :action, :changed_data, :user_id])
    |> validate_length(:table_name, max: 50)
  end
end

# lib/ledger/accounts/account_balance.ex
defmodule Ledger.Accounts.AccountBalance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "account_balances" do
    field :period_year, :integer
    field :period_month, :integer
    field :debit_total, :decimal, default: Decimal.new(0)
    field :credit_total, :decimal, default: Decimal.new(0)
    field :transaction_count, :integer, default: 0
    field :last_updated, :utc_datetime

    belongs_to :account, Ledger.Accounts.Account
  end

  @doc false
  def changeset(balance, attrs) do
    balance
    |> cast(attrs, [:account_id, :period_year, :period_month, :debit_total,
                    :credit_total, :transaction_count])
    |> validate_required([:account_id, :period_year, :period_month])
    |> validate_number(:period_year, greater_than: 2000)
    |> validate_number(:period_month, greater_than: 0, less_than_or_equal_to: 12)
    |> unique_constraint([:account_id, :period_year, :period_month])
    |> foreign_key_constraint(:account_id)
  end
end
```

### 3.2 Context Modules

```elixir
# lib/ledger/accounts.ex
defmodule Ledger.Accounts do
  @moduledoc """
  The Accounts context for managing chart of accounts and users.
  """

  import Ecto.Query, warn: false
  alias Ledger.Repo
  alias Ledger.Accounts.{User, Account, AccountBalance}

  # User functions
  def list_users do
    Repo.all(User)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_external_id(external_id) do
    Repo.get_by(User, external_id: external_id)
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  # Account functions
  def list_accounts do
    Account
    |> preload([:parent, :created_by])
    |> order_by(:code)
    |> Repo.all()
  end

  def list_active_accounts do
    Account
    |> where([a], a.active == true)
    |> order_by(:code)
    |> Repo.all()
  end

  def get_account!(id) do
    Account
    |> preload([:parent, :children, :created_by])
    |> Repo.get!(id)
  end

  def get_account_by_code(code) do
    Repo.get_by(Account, code: code)
  end

  def create_account(attrs \\ %{}) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  def update_account(%Account{} = account, attrs) do
    account
    |> Account.changeset(attrs)
    |> Repo.update()
  end

  def get_account_hierarchy do
    query = """
    WITH RECURSIVE account_tree AS (
      SELECT a.*, 0 as level
      FROM accounts a
      WHERE a.parent_id IS NULL

      UNION ALL

      SELECT a.*, at.level + 1
      FROM accounts a
      INNER JOIN account_tree at ON a.parent_id = at.id
    )
    SELECT * FROM account_tree
    ORDER BY code
    """

    Repo.query!(query)
    |> Map.get(:rows)
    |> Enum.map(&Account.__schema__(:load, :source, %{}, &1))
  end

  # Balance functions
  def get_account_balance(account_id, year, month) do
    AccountBalance
    |> where([b], b.account_id == ^account_id)
    |> where([b], b.period_year == ^year)
    |> where([b], b.period_month == ^month)
    |> Repo.one()
  end

  def update_account_balance(account_id, year, month) do
    # This would typically be called after posting transactions
    # Calculate totals from transaction_lines and update the balance record
  end
end

# lib/ledger/transactions.ex
defmodule Ledger.Transactions do
  @moduledoc """
  The Transactions context for managing journal entries.
  """

  import Ecto.Query, warn: false
  alias Ledger.Repo
  alias Ledger.Transactions.{Transaction, TransactionLine}
  alias Ledger.Audit.AuditLog

  def list_transactions do
    Transaction
    |> preload([:created_by, lines: :account])
    |> order_by([t], desc: t.transaction_date, desc: t.id)
    |> Repo.all()
  end

  def get_transaction!(id) do
    Transaction
    |> preload([:created_by, :posted_by, :voided_by, lines: :account])
    |> Repo.get!(id)
  end

  def create_transaction(attrs \\ %{}) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, transaction} ->
        create_audit_log("transactions", transaction.id, :insert, attrs, attrs["created_by_id"])
        {:ok, Repo.preload(transaction, [:created_by, lines: :account])}
      error -> error
    end
  end

  def update_transaction(%Transaction{} = transaction, attrs) do
    transaction
    |> Transaction.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        create_audit_log("transactions", updated.id, :update, attrs, get_user_id(attrs))
        {:ok, Repo.preload(updated, [:created_by, lines: :account])}
      error -> error
    end
  end

  def post_transaction(%Transaction{status: :draft} = transaction, user_id) do
    attrs = %{
      "status" => "posted",
      "posted_at" => DateTime.utc_now(),
      "posted_by_id" => user_id
    }
    update_transaction(transaction, attrs)
  end

  def void_transaction(%Transaction{status: :posted} = transaction, user_id) do
    attrs = %{
      "status" => "void",
      "voided_at" => DateTime.utc_now(),
      "voided_by_id" => user_id
    }
    update_transaction(transaction, attrs)
  end

  def get_trial_balance(date \\ Date.utc_today()) do
    query = """
    SELECT
      a.id,
      a.code,
      a.name,
      COALESCE(SUM(CASE WHEN tl.amount > 0 THEN tl.amount ELSE 0 END), 0) as debit_total,
      COALESCE(SUM(CASE WHEN tl.amount < 0 THEN ABS(tl.amount) ELSE 0 END), 0) as credit_total,
      COALESCE(SUM(tl.amount), 0) as balance
    FROM accounts a
    LEFT JOIN transaction_lines tl ON a.id = tl.account_id
    LEFT JOIN transactions t ON tl.transaction_id = t.id
    WHERE t.status = 'posted' AND t.transaction_date <= $1
    GROUP BY a.id, a.code, a.name
    ORDER BY a.code
    """

    Repo.query!(query, [date])
  end

  defp create_audit_log(table_name, record_id, action, changed_data, user_id) do
    %AuditLog{}
    |> AuditLog.changeset(%{
      table_name: table_name,
      record_id: record_id,
      action: action,
      changed_data: changed_data,
      user_id: user_id
    })
    |> Repo.insert()
  end

  defp get_user_id(attrs) do
    attrs["posted_by_id"] || attrs["voided_by_id"] || attrs["created_by_id"]
  end
end

# lib/ledger/templates.ex
defmodule Ledger.Templates do
  @moduledoc """
  The Templates context for managing transaction templates.
  """

  import Ecto.Query, warn: false
  alias Ledger.Repo
  alias Ledger.Templates.{Template, TemplateLine}

  def list_templates do
    Template
    |> preload([:created_by, lines: :account])
    |> order_by(:code)
    |> Repo.all()
  end

  def list_active_templates do
    Template
    |> where([t], t.active == true)
    |> preload([lines: :account])
    |> order_by(:code)
    |> Repo.all()
  end

  def get_template!(id) do
    Template
    |> preload([:created_by, lines: :account])
    |> Repo.get!(id)
  end

  def get_template_by_code(code) do
    Template
    |> where([t], t.code == ^code)
    |> preload([lines: :account])
    |> Repo.one()
  end

  def create_template(attrs \\ %{}) do
    %Template{}
    |> Template.changeset(attrs)
    |> Repo.insert()
  end

  def update_template(%Template{} = template, attrs) do
    template
    |> Template.changeset(attrs)
    |> Repo.update()
  end

  def apply_template(%Template{} = template, total_amount \\ nil) do
    lines = Enum.map(template.lines, fn line ->
      line_amount = calculate_line_amount(line, total_amount)
      %{
        account_id: line.account_id,
        description: line.description,
        amount: if(line.line_type == :debit, line_amount, Decimal.negate(line_amount)),
        tax_relevant: line.tax_relevant,
        position: line.position
      }
    end)

    # Ensure balanced transaction by adjusting rounding differences
    total = calculate_total(lines)

    if Decimal.eq?(total, 0) do
      {:ok, lines}
    else
      {:ok, balance_lines(lines, total)}
    end
  end

  defp calculate_line_amount(%TemplateLine{amount_type: :fixed} = line, _total) do
    line.amount_value
  end

  defp calculate_line_amount(%TemplateLine{amount_type: :percentage} = line, total) do
    total
    |> Decimal.mult(line.amount_value)
    |> Decimal.div(100)
    |> Decimal.round(2)
  end

  defp calculate_total(lines) do
    Enum.reduce(lines, Decimal.new(0), fn line, acc ->
      Decimal.add(acc, line.amount)
    end)
  end

  defp balance_lines(lines, total) do
    # Add rounding difference to the last line to ensure zero balance
    last_index = length(lines) - 1

    List.update_at(lines, last_index, fn line ->
      Map.update!(line, :amount, &Decimal.sub(&1, total))
    end)
  end
end
```

### 3.3 Migrations

```elixir
# priv/repo/migrations/001_enable_foreign_keys.exs
defmodule Ledger.Repo.Migrations.EnableForeignKeys do
  use Ecto.Migration

  def up do
    execute "PRAGMA foreign_keys = ON"
  end

  def down do
    execute "PRAGMA foreign_keys = OFF"
  end
end

# priv/repo/migrations/002_create_users.exs
defmodule Ledger.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :external_id, :uuid, null: false
      add :username, :string, null: false
      add :role, :string, null: false, default: "viewer"

      timestamps()
    end

    create unique_index(:users, [:external_id])
    create unique_index(:users, [:username])
  end
end

# priv/repo/migrations/003_create_accounts.exs
defmodule Ledger.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :code, :string, null: false
      add :name, :string, null: false
      add :parent_id, references(:accounts, on_delete: :restrict)
      add :description, :text
      add :active, :boolean, default: true, null: false
      add :created_by_id, references(:users, on_delete: :restrict), null: false

      timestamps()
    end

    create unique_index(:accounts, [:code])
    create index(:accounts, [:parent_id])

    execute """
    CREATE TRIGGER update_accounts_timestamp
    AFTER UPDATE ON accounts
    BEGIN
      UPDATE accounts SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
    END;
    """
  end
end

# Additional migration files would follow for the rest of the tables...
```

### 3.4 Custom Types

```elixir
# lib/ledger/types/amount.ex
defmodule Ledger.Types.Amount do
  @moduledoc """
  Custom Decimal type for monetary amounts with specific rounding behavior.
  """

  use Ecto.Type

  def type, do: :decimal

  def cast(value) when is_binary(value) do
    case Decimal.parse(value) do
      {:ok, decimal} -> {:ok, Decimal.round(decimal, 2)}
      :error -> :error
    end
  end

  def cast(%Decimal{} = value) do
    {:ok, Decimal.round(value, 2)}
  end

  def cast(value) when is_integer(value) or is_float(value) do
    {:ok, Decimal.new(value) |> Decimal.round(2)}
  end

  def cast(_), do: :error

  def load(value) do
    {:ok, Decimal.new(value)}
  end

  def dump(%Decimal{} = value) do
    {:ok, Decimal.to_string(value, :normal)}
  end

  def dump(_), do: :error

  @doc """
  Distributes an amount across n parts, ensuring the total equals the original.
  """
  def distribute(amount, n) when is_integer(n) and n > 0 do
    base_amount = amount
    |> Decimal.div(n)
    |> Decimal.round(2, :down)

    remainder = amount
    |> Decimal.sub(Decimal.mult(base_amount, n))

    # Create list with base amounts
    base_list = List.duplicate(base_amount, n)

    # Distribute remainder cents
    remainder_cents = remainder
    |> Decimal.mult(100)
    |> Decimal.round(0)
    |> Decimal.to_integer()

    distribute_remainder(base_list, remainder_cents, [])
  end

  defp distribute_remainder([], 0, acc), do: Enum.reverse(acc)

  defp distribute_remainder([head | tail], remainder, acc) when remainder > 0 do
    distribute_remainder(tail, remainder - 1, [Decimal.add(head, Decimal.new("0.01")) | acc])
  end

  defp distribute_remainder([head | tail], remainder, acc) do
    distribute_remainder(tail, remainder, [head | acc])
  end
end
```

### 3.5 Query Helpers

```elixir
# lib/ledger/queries/account_queries.ex
defmodule Ledger.Queries.AccountQueries do
  import Ecto.Query

  alias Ledger.Accounts.Account
  alias Ledger.Transactions.TransactionLine

  def with_balance(query \\ Account) do
    from a in query,
      left_join: tl in TransactionLine,
      on: tl.account_id == a.id,
      left_join: t in assoc(tl, :transaction),
      where: is_nil(t.id) or t.status == :posted,
      group_by: a.id,
      select: %{
        a |
        debit_total: coalesce(sum(fragment("CASE WHEN ? > 0 THEN ? ELSE 0 END", tl.amount, tl.amount)), 0),
        credit_total: coalesce(sum(fragment("CASE WHEN ? < 0 THEN ABS(?) ELSE 0 END", tl.amount, tl.amount)), 0),
        balance: coalesce(sum(tl.amount), 0)
      }
  end

  def active(query \\ Account) do
    from a in query, where: a.active == true
  end

  def with_children(query \\ Account) do
    from a in query, preload: [:children]
  end
end

# lib/ledger/queries/transaction_queries.ex
defmodule Ledger.Queries.TransactionQueries do
  import Ecto.Query

  alias Ledger.Transactions.Transaction

  def by_date_range(query \\ Transaction, start_date, end_date) do
    from t in query,
      where: t.transaction_date >= ^start_date and t.transaction_date <= ^end_date
  end

  def by_status(query \\ Transaction, status) do
    from t in query, where: t.status == ^status
  end

  def with_lines(query \\ Transaction) do
    from t in query, preload: [lines: :account]
  end

  def by_account(query \\ Transaction, account_id) do
    from t in query,
      join: tl in assoc(t, :lines),
      where: tl.account_id == ^account_id,
      distinct: true
  end

  def unbalanced(query \\ Transaction) do
    from t in query,
      join: tl in assoc(t, :lines),
      group_by: t.id,
      having: sum(tl.amount) != 0
  end
end
```
