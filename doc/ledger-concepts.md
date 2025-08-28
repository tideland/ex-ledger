# Tideland Ledger - Core Ledger Concepts

## 1. Double-Entry Bookkeeping Model

### 1.1 Transaction Structure

A transaction in our ledger system consists of:

- **Transaction metadata**: Date, description, reference number, user who created it
- **Multiple positions** (also called entries or line items)
- **Validation rule**: The sum of all positions must equal zero

### 1.2 Position (Entry) Structure

Each position within a transaction contains:

- Reference to an account
- Amount (positive or negative)
- Optional: Description/memo for this specific position
- Optional: Additional metadata (cost center, project, etc.)

### 1.3 Zero-Sum Validation

The fundamental rule: For every transaction, the sum of all position amounts must equal zero.

Example:

```
Transaction: "Purchase office supplies with cash"
- Position 1: Office Supplies Account: +50.00
- Position 2: Cash Account: -50.00
- Sum: +50.00 + (-50.00) = 0.00 ✓
```

## 2. Account Organization and Conventions

### 2.1 Account Structure

In the ledger system, all accounts are equal - there are no enforced types. The meaning and grouping of accounts is determined by:

1. **Account Code/Number**: Following standard numbering schemes (e.g., SKR03, SKR04 for German accounting)
2. **Account Name**: Descriptive names that indicate the account's purpose
3. **Account Hierarchy**: Parent-child relationships for organizational structure

### 2.2 Accounting Conventions (Not System-Enforced)

While the ledger doesn't enforce account types, accounting conventions typically organize accounts as:

1. **Assets** (Aktiva) - e.g., codes 0000-1999 in SKR03
   - Convention: Debit increases, credit decreases
   - Examples: Cash, Bank accounts, Inventory, Equipment

2. **Liabilities** (Passiva/Verbindlichkeiten) - e.g., codes 3000-3999 in SKR03
   - Convention: Credit increases, debit decreases
   - Examples: Loans, Accounts payable

3. **Equity** (Eigenkapital) - e.g., codes 2000-2999 in SKR03
   - Convention: Credit increases, debit decreases
   - Examples: Capital, Retained earnings

4. **Revenue/Income** (Erträge) - e.g., codes 8000-8999 in SKR03
   - Convention: Credit increases, debit decreases
   - Examples: Sales, Service income

5. **Expenses** (Aufwendungen) - e.g., codes 4000-7999 in SKR03
   - Convention: Debit increases, credit decreases
   - Examples: Rent, Salaries, Utilities

### 2.3 The Fundamental Rule

The only enforced rule in the ledger: **Every transaction must balance to zero**.

The accounting equation (Assets = Liabilities + Equity + Revenue - Expenses) is a reporting convention built on top of the ledger data, not enforced by the system itself.

## 3. Transaction Examples

### 3.1 Simple Purchase

```
Transaction: "Buy laptop for 1,200.00"
Date: 2024-01-15
Positions:
  1. Account 0620 (Equipment):     +1,200.00
  2. Account 1200 (Bank Account):  -1,200.00
Sum: 0.00 ✓
```

### 3.2 Revenue Transaction

```
Transaction: "Invoice client for services"
Date: 2024-01-20
Positions:
  1. Account 1400 (Accounts Receivable):  +5,000.00
  2. Account 8400 (Service Revenue):      -5,000.00
Sum: 0.00 ✓
```

### 3.3 Complex Transaction with Multiple Accounts

```
Transaction: "Pay invoice with early payment discount"
Date: 2024-01-25
Positions:
  1. Accounts Payable (Liability):  +1,000.00  // Reducing liability
  2. Bank Account (Asset):          -980.00    // Payment made
  3. Discounts Earned (Revenue):    -20.00     // Discount revenue
Sum: +1,000.00 - 980.00 - 20.00 = 0.00 ✓
```

### 3.4 Multi-Position Split

```
Transaction: "Monthly rent payment including utilities"
Date: 2024-02-01
Positions:
  1. Rent Expense:            +800.00
  2. Utilities Expense:       +150.00
  3. Maintenance Expense:     +50.00
  4. Bank Account (Asset):    -1,000.00
Sum: +800.00 + 150.00 + 50.00 - 1,000.00 = 0.00 ✓
```

## 4. Implementation Considerations

### 4.1 Amount Representation

- All amounts stored as signed decimals
- Positive amounts represent debits
- Negative amounts represent credits
- This eliminates the need for separate debit/credit columns

### 4.2 Validation Rules

1. **Zero-sum rule**: Transaction positions must sum to zero
2. **Minimum positions**: At least 2 positions per transaction
3. **Non-zero amounts**: Each position must have a non-zero amount
4. **Valid accounts**: Each position must reference an existing account

### 4.3 Transaction States

- **Draft**: Can be edited, not yet validated
- **Posted**: Validated and immutable
- **Reversed**: Cancelled by a reversing transaction (not deleted)

## 5. Account Hierarchy and Chart of Accounts

### 5.1 Account Structure

Accounts are organized in a hierarchical path-based structure, similar to file system directories:

```
Assets
  Assets : Current Assets
    Assets : Current Assets : Cash
    Assets : Current Assets : Bank Accounts
      Assets : Current Assets : Bank Accounts : Checking Account
      Assets : Current Assets : Bank Accounts : Savings Account
  Assets : Fixed Assets
    Assets : Fixed Assets : Equipment
    Assets : Fixed Assets : Vehicles

Liabilities
  Liabilities : Current Liabilities
    Liabilities : Current Liabilities : Accounts Payable
  Liabilities : Long-term Liabilities
    Liabilities : Long-term Liabilities : Loans

Equity
  Equity : Capital
  Equity : Retained Earnings

Revenue
  Revenue : Sales Revenue
  Revenue : Service Revenue

Expenses
  Expenses : Operating Expenses
    Expenses : Operating Expenses : Rent
    Expenses : Operating Expenses : Salaries
  Expenses : Administrative Expenses
```

### 5.2 Account Properties

- **Path**: Full hierarchical path (e.g., "Assets : Current Assets : Bank Accounts : Checking Account")
- **Name**: The last component of the path (e.g., "Checking Account")
- **Type**: Derived from the root component (Asset, Liability, Equity, Revenue, or Expense)
- **Parent Path**: The path without the last component (e.g., "Assets : Current Assets : Bank Accounts")
- **Active**: Boolean flag for soft deletion

### 5.3 Path-Based Benefits

- **Self-documenting**: The full path provides complete context
- **No numeric codes needed**: Eliminates arbitrary numbering schemes
- **Natural hierarchy**: Similar to file system navigation
- **Flexible depth**: Can add levels as needed without renumbering
- **Readable**: Human-friendly naming throughout the system

## 6. Balance Calculation

### 6.1 Account Balance

The balance of an account is the sum of all position amounts for that account across all posted transactions.

Example:

```
Bank Account (Assets : Current Assets : Bank Accounts) positions:
- Initial deposit:     +10,000.00
- Laptop purchase:     -1,200.00
- Client payment:      +5,000.00
- Rent payment:        -1,000.00
Current Balance:       +12,800.00
```

### 6.2 Trial Balance

A report showing all accounts with their balances. The sum of all account balances should equal zero (proving the books are in balance).

## 7. Template System for Transactions

### 7.1 Template Structure

Templates store predefined transaction patterns:

- Template name and description
- Default positions with:
  - Account references
  - Amount formulas or fixed amounts
  - Percentage distributions

### 7.2 Template Example

```
Template: "Monthly Rent"
Positions:
  1. Rent Expense:        +{amount * 0.80}
  2. Utilities Expense:   +{amount * 0.15}
  3. Maintenance:         +{amount * 0.05}
  4. Bank Account:        -{amount}
```

When used with amount = 1,000.00, creates the transaction shown in example 3.4.

## 8. Amount Distribution for Splits

### 8.1 The Distribution Problem

When splitting amounts (e.g., 100.00 / 3), rounding can create imbalances.

### 8.2 Our Solution

The Amount type provides a distribution function that ensures the sum equals the original amount:

```
distribute(100.00, 3) = [33.33, 33.33, 33.34]
Sum: 33.33 + 33.33 + 33.34 = 100.00 ✓
```

This is crucial for maintaining the zero-sum rule when splitting transactions among multiple accounts.
