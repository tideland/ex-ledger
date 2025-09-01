# Tideland Ledger - Glossary

This glossary defines the canonical terminology used throughout the Tideland Ledger system. Each term is provided in English with its German translation and a clear definition.

## Core Accounting Terms

### Account / Konto

A named container for tracking financial transactions. Accounts are organized hierarchically using colon separators (e.g., "Einnahmen : Arbeit : Tideland").

### Amount / Betrag

A monetary value with exactly two decimal places, stored internally as cents/minor units to avoid floating-point precision issues.

### Balance / Saldo

The current sum of all entries for a specific account or group of accounts.

### Entry / Buchung

A single financial transaction recorded in the ledger, consisting of a date, description, amount, and associated account.

### Ledger / Hauptbuch

The complete collection of all financial entries and accounts in the system.

### Period / Periode

A time span (month, quarter, or year) that can be closed to prevent further modifications.

### Position / Position

An individual line item within an entry, specifying an account and amount. In our simplified ledger, each entry must have at least two positions that balance to zero.

### Posting / Buchen

The action of recording an entry in the ledger, making it permanent and immutable.

### Template / Vorlage

A reusable pattern for creating similar entries, with predefined accounts and optional default amounts.

### Transaction / Transaktion

Synonym for Entry. A recorded financial event in the ledger.

## User and Security Terms

### Admin / Administrator

A user role with full system access, including user management and the ability to bypass period locks.

### Bookkeeper / Buchhalter

A user role that can create and post entries within open periods.

### Role / Rolle

A set of permissions assigned to users, determining what actions they can perform in the system.

### User / Benutzer

An individual with authenticated access to the ledger system.

### Viewer / Betrachter

A user role with read-only access to view reports and account information.

## Technical Terms

### Audit Log / Revisionssicherung

An append-only record of all system changes for compliance and security purposes.

### Export / Export

The process of extracting ledger data in CSV or JSON format for external use.

### Import / Import

The process of loading external data into the ledger from CSV or JSON files.

### Migration / Migration

Database schema changes applied incrementally to update the system structure.

### Report / Bericht

A formatted view of ledger data, such as account balances or transaction listings.

### Reversal / Stornierung

A correcting entry that cancels out a previous entry, maintaining the immutability principle.

### Session / Sitzung

An authenticated user's active connection to the system.

### Validation / Validierung

The process of checking that data meets all required constraints before saving.

## Account Hierarchy Terms

### Child Account / Unterkonto

An account that exists below another account in the hierarchy (e.g., "Ausgaben : Büro : Material" is a child of "Ausgaben : Büro").

### Parent Account / Oberkonto

An account that contains other accounts in the hierarchy (e.g., "Ausgaben" is the parent of "Ausgaben : Büro").

### Root Account / Stammkonto

A top-level account with no parent (e.g., "Einnahmen", "Ausgaben", "Vermögen").

### Separator / Trennzeichen

The normalized " : " (space-colon-space) used to indicate hierarchy levels in account names.

## Amount Handling Terms

### Distribution / Verteilung

The process of fairly splitting an amount across multiple positions, ensuring the sum equals the original amount.

### Precision / Genauigkeit

The number of decimal places used for monetary amounts (fixed at 2 for EUR).

### Rounding / Rundung

The banker's rounding method used when dividing amounts to ensure consistent results.

### Scale / Skalierung

The internal representation of amounts as integers (cents) to avoid floating-point errors.

## Reporting Terms

### As-of Date / Stichtagsdatum

A specific date for which a report shows the state of accounts, including all entries up to that date.

### Balance Sheet / Bilanz

A report showing the financial position at a specific date, listing all account balances.

### Date Range / Zeitraum

The period between a start and end date used to filter entries for reports.

### Trial Balance / Rohbilanz

A report listing all accounts with their debit and credit totals, used to verify accounting accuracy.

## System Terms

### Backup / Sicherung

A copy of the database file for disaster recovery purposes.

### Configuration / Konfiguration

System settings stored in TOML files, controlling behavior without code changes.

### Deployment / Bereitstellung

The process of installing and running the ledger system on a server.

### Instance / Instanz

A single installation of the ledger system, serving one organization.

### Seed Data / Stammdaten

Initial accounts and templates loaded when setting up a new ledger instance.

## Usage Notes

1. All user interface text uses the German terms
2. All source code, comments, and documentation use the English terms
3. Account names may be entered in either language but are stored as entered
4. This glossary is the authoritative source for terminology consistency
