# Tideland Ledger - Formal Specification

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

## Table of Contents

1. [Overview](#1-overview)
2. [How to Read This Specification](#2-how-to-read-this-specification)
3. [Core System Requirements](#3-core-system-requirements)
4. [Accounting Domain Requirements](#4-accounting-domain-requirements)
5. [User Interface Requirements](#5-user-interface-requirements)
6. [Security Requirements](#6-security-requirements)
7. [Data Management Requirements](#7-data-management-requirements)
8. [Configuration Requirements](#8-configuration-requirements)
9. [Development Requirements](#9-development-requirements)
10. [Related Documents](#10-related-documents)

## 1. Overview

This document provides a formal specification for the Tideland Ledger system, consolidating all requirements with their constraints, chosen solutions, and rationales for each decision.

## 2. How to Read This Specification

This specification is organized as a comprehensive reference for the Tideland Ledger system. Each requirement follows a consistent format:

- **Requirement**: The core need to be addressed
- **Constraints**: Limitations and boundaries that shape the solution
- **Solution**: The chosen approach to meet the requirement
- **Rationale**: The reasoning behind the chosen solution

### Document Structure

1. **Core System Requirements** (REQ-001 to REQ-007): Foundational technology choices and architecture
2. **Accounting Domain Requirements** (REQ-008 to REQ-018): Business logic and bookkeeping rules
3. **User Interface Requirements** (REQ-019 to REQ-020): User experience and interaction design
4. **Security Requirements** (REQ-021): Authentication and authorization
5. **Additional Requirements**: Testing, documentation, and operational concerns

### Related Design Documents

For detailed implementation guidance, refer to these companion documents:

- `persistence-design.md`: Database schema, indexes, and data access patterns
- `wui-design.md`: LiveView components and user interface implementation
- `dsl-design.md`: Domain-specific language for account and transaction definitions
- `configuration-design.md`: TOML configuration structure and settings
- `ledger-concepts.md`: Accounting principles and domain concepts
- `glossary.md`: Canonical terminology with English/German translations
- `impexp-design.md`: Import/export specifications and data formats

- `auth-design.md`: Authentication system design with future extraction plan

## 3. Core System Requirements

### REQ-01-01: Programming Language and Framework

**Requirement**: The system must be implemented in Elixir using the Phoenix Framework.

**Constraints**:

- Developer is new to Elixir but experienced in other languages
- Must serve as a learning project
- Should follow Elixir/OTP best practices

**Solution**: Pure Elixir/Phoenix implementation with OTP supervision trees

**Rationale**: Elixir provides excellent fault tolerance, concurrent processing capabilities, and clean functional programming patterns ideal for financial calculations. Phoenix offers a mature web framework with LiveView for real-time UI without JavaScript complexity.

### REQ-01-02: Database System

**Requirement**: Use SQLite for data persistence.

**Constraints**:

- Must support ACID transactions
- Should be simple to deploy and backup
- No need for distributed database features

**Solution**: Ecto with SQLite3 adapter

**Rationale**: SQLite provides full ACID compliance, zero-configuration deployment, and simple file-based backups. Perfect for single-tenant bookkeeping systems where all data fits on one machine.

### REQ-01-03: User Interface Technology

**Requirement**: Web-based user interface without Node.js or complex JavaScript frameworks.

**Constraints**:

- No Node.js in the build pipeline
- Minimal client-side JavaScript
- Must provide real-time feedback for data entry

**Solution**: Phoenix LiveView with server-side rendering

**Rationale**: LiveView provides real-time interactivity through WebSockets while keeping all logic in Elixir. This eliminates JavaScript complexity while delivering modern UX. The ~29KB LiveView runtime is maintained by the Phoenix team.

### REQ-01-04: Configuration Management

**Requirement**: All configuration must be externalized to TOML files.

**Constraints**:

- No hardcoded configuration except roles and admin user
- Must support different deployment environments
- Configuration should be human-readable

**Solution**: TOML configuration files with custom Config.Provider

**Rationale**: TOML is more readable than JSON or YAML for configuration. It's well-supported in Elixir and allows comments. The Config.Provider pattern enables runtime configuration changes.

## 4. Authentication and Authorization Requirements

### REQ-02-01: Authentication System

**Requirement**: Built-in authentication system for the ledger application.

**Constraints**:

- Implement authentication within the application
- Support standard authentication features (login, logout, sessions)
- Secure password handling with bcrypt/argon2
- Three hardcoded roles: Admin, Bookkeeper, Viewer

**Solution**: Built-in authentication with secure session management

**Rationale**: Self-contained authentication eliminates external dependencies and simplifies deployment while providing all necessary security features for a bookkeeping application.

### REQ-02-02: Authorization Roles

**Requirement**: Three hardcoded roles: Admin, Bookkeeper (Buchhalter), Viewer (Betrachter).

**Constraints**:

- Roles must be hardcoded, not configurable
- Initial "admin" user created on first startup
- Role-based permissions for all operations
- Admin can manage other users within the system

**Solution**: Hardcoded role definitions with permission matrices

**Rationale**: Fixed roles simplify the authorization model and ensure consistent permissions across deployments. The initial admin account ensures system bootstrap capability.

### REQ-02-03: Single-Tenant Architecture

**Requirement**: Single-tenant system with one set of books shared by all users.

**Constraints**:

- No user-specific books
- All users see the same data (based on permissions)
- No data isolation between users

**Solution**: Single database schema without tenant isolation

**Rationale**: Simplifies the data model and matches typical small business needs where all users work on the same set of books.

## 5. Accounting Domain Requirements

### REQ-03-01: Simplified Ledger-Style Bookkeeping

**Requirement**: Implement simplified ledger-style bookkeeping.

**Constraints**:

- No double-entry with debit/credit
- Simple income and expense tracking
- No system-enforced account types
- Entries must have at least 2 positions that balance to zero

**Solution**: Entry model with positions, simplified validation

**Rationale**: Simplified ledger style provides ease of use for basic bookkeeping needs without the complexity of double-entry accounting.

### REQ-03-02: Account Structure

**Requirement**: Hierarchical account structure using string-based naming.

**Constraints**:

- Accounts are strings with hierarchy indicated by colons
- Separator normalized to " : " (space-colon-space)
- Must support parent-child relationships

**Solution**: String-based account hierarchy (e.g., "Einnahmen : Arbeit : Tideland")

**Rationale**: Path-based structure is self-documenting and eliminates the need for separate parent ID tracking. It mirrors file system paths, making it intuitive.

### REQ-03-03: Amount Representation

**Requirement**: Signed decimal amounts instead of separate debit/credit fields.

**Constraints**:

- Must maintain precision for currency (2 decimal places)
- Positive represents debit, negative represents credit
- Must handle distribution/splitting correctly

**Solution**: Custom Amount type based on Decimal with signed values

**Rationale**: Signed amounts simplify data entry and calculations. Users enter +1500 or -1500 instead of choosing debit/credit columns. This is more intuitive for non-accountants.

### REQ-03-04: Entry Voiding via Reversal

**Requirement**: Voided entries are handled through automatic reversal entries.

**Constraints**:

- Original entries remain immutable after posting
- Void operation creates compensating reversal entry
- Reversal entry is automatically posted
- Audit trail maintained with void reason

**Solution**: Automatic reversal generation with negated amounts

**Rationale**: This approach maintains complete audit trail and ensures data integrity. The original entry remains for historical accuracy while the reversal cancels its financial effect.

### REQ-03-05: Amount Distribution

**Requirement**: Correct distribution when splitting amounts (e.g., 100/3).

**Constraints**:

- Sum of distributed amounts must equal original
- Rounding must not create imbalances
- Must work for any number of splits

**Solution**: Distribution function that adds remainder to last amount

**Rationale**: Ensures transaction balance is maintained even with rounding. Example: 100/3 = [33.33, 33.33, 33.34].

### REQ-03-06: Entry Templates

**Requirement**: Reusable entry templates with fractional distribution.

**Constraints**:

- Templates must validate against existing accounts
- Support both fixed amounts and percentages
- Fractions as standard approach (not special case)

**Solution**: Template system with fraction-based position definitions

**Rationale**: Fractions/percentages are more flexible than fixed amounts. A rent template can work whether rent is 1000 or 1500 by using fractions.

### REQ-03-07: Tax Relevance Tracking

**Requirement**: Mark individual positions as tax-relevant.

**Constraints**:

- Must be at position level, not transaction level
- Support German tax requirements
- Example: Split craftsman invoice into deductible labor and non-deductible materials

**Solution**: Boolean tax_relevant flag on each position

**Rationale**: German tax law often requires splitting invoices. Position-level tracking provides the necessary granularity.

## 6. User Interface Requirements

### REQ-04-01: Language

**Requirement**: German-only user interface.

**Constraints**:

- All UI text in German
- Source code and documentation in English
- Database content in user's language (German)

**Solution**: Gettext for German translations, English variable names

**Rationale**: The application targets German users. Keeping code in English maintains compatibility with the broader Elixir ecosystem.

### REQ-04-02: Visual Design

**Requirement**: Simple, flat design like mainframe terminals.

**Constraints**:

- No gradients, shadows, or complex CSS
- Menu items as full clickable areas
- Minimal color usage
- No animations

**Solution**: Basic CSS with flat design, vertical navigation menu

**Rationale**: Simplicity reduces maintenance and focuses users on functionality rather than aesthetics. Terminal-like design reinforces the "tool" nature of the application.

### REQ-04-03: Navigation Structure

**Requirement**: Clear, flat navigation without dropdowns.

**Constraints**:

- All functions accessible within 2 clicks
- No nested menus
- Vertical menu for variable page widths
- URL paths in standard English with kebab-case for multi-word terms

**Solution**: Fixed vertical navigation with main sections and standardized URL paths

**Example URL paths**:

- `/` (Dashboard) - UI text: "Übersicht"
- `/entries` (Entries list) - UI text: "Buchungen"
- `/entries/new` (New entry) - UI text: "Neue Buchung"
- `/entries/:id` (View entry) - UI text: "Buchung anzeigen"
- `/entries/:id/edit` (Edit entry) - UI text: "Buchung bearbeiten"
- `/accounts` (Accounts list) - UI text: "Konten"
- `/templates` (Templates) - UI text: "Vorlagen"
- `/reports` (Reports) - UI text: "Berichte"
- `/users` (Users) - UI text: "Benutzer"

**Rationale**: Vertical menus work better with unknown page widths and provide room for German text. Flat navigation reduces cognitive load. Standard English URLs with kebab-case follow web conventions and improve interoperability, while the UI text remains in German as specified in REQ-04-01: Language.

## 7. Data Entry Requirements

### REQ-05-01: Entry Creation

**Requirement**: Efficient entry creation with real-time validation.

**Constraints**:

- Must show running balance
- Validate zero-sum before saving
- Support dynamic position adding/removal

**Solution**: LiveView form with real-time sum calculation

**Rationale**: Immediate feedback prevents errors. LiveView eliminates round-trips while keeping logic server-side.

### REQ-05-02: Account Selection

**Requirement**: Account selection supporting hierarchical paths.

**Constraints**:

- Must show full account path
- Searchable by any part of path
- Wide enough for long hierarchical names

**Solution**: Searchable dropdown showing full paths

**Rationale**: Full paths provide context. Search enables quick selection even with hundreds of accounts.

### REQ-05-03: Date Handling

**Requirement**: ISO 8601 date format throughout the system.

**Constraints**:

- Consistent sorting
- Unambiguous format
- International standard

**Solution**: YYYY-MM-DD format everywhere

**Rationale**: ISO 8601 eliminates ambiguity between DD/MM and MM/DD formats and sorts naturally.

## 8. Reporting Requirements

### REQ-06-01: Standard Reports

**Requirement**: Generate standard accounting reports.

**Constraints**:

- Trial balance (Probebilanz)
- Balance sheet (Bilanz)
- Account statements (Kontoauszug)
- Must reflect German accounting standards

**Solution**: Report modules interpreting account codes by convention

**Rationale**: Since account types aren't system-enforced, reports interpret accounts based on their codes according to the chosen numbering scheme.

### REQ-06-02: Export Capabilities

**Requirement**: Export reports in common formats.

**Constraints**:

- CSV for data processing
- PDF for archival (future)
- Maintain number formatting

**Solution**: Initial CSV export, PDF planned for later

**Rationale**: CSV provides immediate value for Excel users. PDF can be added when needed.

## 9. Security and Authorization Requirements

### REQ-07-01: Authentication Security

**Requirement**: Secure authentication implementation following best practices.

**Constraints**:

- Passwords hashed with bcrypt or argon2
- Session management with secure tokens
- CSRF protection for all state-changing operations
- Secure cookie configuration

**Solution**: Phoenix built-in security features with proper configuration

**Rationale**: Security is critical for financial applications. Using Phoenix's built-in security features ensures battle-tested implementations.

### REQ-07-02: Role-Based Access Control

**Requirement**: Enforce role-based permissions throughout the system.

**Constraints**:

- Admin: Full system access
- Bookkeeper: Create and post transactions
- Viewer: Read-only access

**Solution**: Plug-based authorization with role checks

**Rationale**: Consistent authorization ensures data security and prevents unauthorized operations.

## 10. Code Quality Requirements

### REQ-08-01: Code Organization

**Requirement**: Follow Elixir and Phoenix conventions.

**Constraints**:

- Domain-driven design with contexts
- Clear separation of concerns
- Comprehensive documentation

**Solution**: Phoenix contexts, separate business logic from web layer

**Rationale**: Good organization is crucial for maintainability, especially in a learning project.

### REQ-08-02: Documentation Standards

**Requirement**: Comprehensive, semantically meaningful documentation at all levels.

**Constraints**:

- Module documentation with purpose, responsibility, and examples
- Function specs with @doc and @spec describing semantics, not implementation
- Comments focused on explaining the "why" behind business decisions
- Protocol implementations documented with business purpose and usage context
- External framework interactions documented with clear integration points
- Ledger-specific accounting terminology used consistently (avoid double-entry terms)
- Domain-specific terminology linked to the glossary
- Public APIs documented with complete usage examples

**Solution**:

- ExDoc with comprehensive @moduledoc and @doc
- Semantic documentation focused on business meaning
- Clear separation between framework integration and business logic
- Explicit documentation of system boundaries and integration points

**Rationale**:

- Good documentation focuses on meaning rather than implementation details
- Semantic understanding of the system is more valuable than technical minutiae
- Maintaining clear terminology prevents conceptual confusion
- Documentation should be valuable for all developers regardless of experience level
- Understanding business context is crucial for maintaining accounting systems

### REQ-08-03: Testing Strategy

**Requirement**: Comprehensive test coverage.

**Constraints**:

- Unit tests for business logic
- Integration tests for workflows
- Property-based tests for Amount type

**Solution**: ExUnit with proper test organization

**Rationale**: Good test coverage is essential for financial software. Database sandboxing enables parallel test execution.

### REQ-08-04: Error Handling

**Requirement**: Graceful error handling with user-friendly messages.

**Constraints**:

- Never show technical errors to users
- Log technical details for debugging
- Provide recovery suggestions
- Business logic returns error atoms/symbols only
- Translation happens at the UI layer

**Solution**: Error atoms in business logic, translation module in UI layer

**Rationale**: Users need clear guidance when errors occur. Technical details belong in logs, not user interfaces. Separating error symbols from translations enables proper internationalization.

### REQ-08-05: Internationalization Architecture

**Requirement**: Clear separation between business logic and UI translations.

**Constraints**:

- Business logic modules return only atoms or tuples for errors
- No hardcoded user-facing strings in schemas or contexts
- All translation happens in the web layer
- German as primary UI language

**Solution**: Dedicated translation module (ErrorMessages) in web layer

**Rationale**: This separation enables future multi-language support and keeps business logic pure. It also makes testing easier as business logic tests don't depend on specific message strings.

## 11. Deployment Requirements

### REQ-09-01: Package Distribution

**Requirement**: Distribute as Hex package "tideland-ledger".

**Constraints**:

- Follow Elixir naming conventions
- Repository at github.com/tideland/ex-ledger
- Semantic versioning

**Solution**: Standard Hex package with mix release support

**Rationale**: Hex is the standard package manager for Elixir. The naming follows Tideland conventions.

### REQ-09-02: Configuration Deployment

**Requirement**: Support multiple deployment scenarios.

**Constraints**:

- Development with local files
- Production with system paths
- Docker containers

**Solution**: Configurable paths with sensible defaults

**Rationale**: Different deployment targets have different filesystem conventions. Configurability enables flexibility.

### REQ-09-03: Database Location

**Requirement**: Configurable SQLite database location.

**Constraints**:

- Development: local directory
- Production: system directory
- Must be backup-friendly

**Solution**: Path configuration in TOML with platform defaults

**Rationale**: SQLite databases are files, making backup simple. Platform-specific defaults follow OS conventions.

## 12. Performance Requirements

### REQ-10-01: Response Times

**Requirement**: Sub-second response for common operations.

**Constraints**:

- Entry creation
- Report generation for < 10,000 entries
- Account balance queries

**Solution**: Indexed database queries, LiveView debouncing

**Rationale**: Users expect responsive interfaces. Proper indexing and debouncing prevent performance issues.

### REQ-10-02: Scalability

**Requirement**: Handle thousands of entries efficiently.

**Constraints**:

- Single SQLite database
- Limited by disk I/O
- No distributed processing

**Solution**: Pagination, efficient queries, denormalized balances

**Rationale**: SQLite can handle millions of rows. Pagination and smart queries keep the UI responsive.

## 13. Future Considerations

### REQ-11-01: CSV Import

**Requirement**: Import entries from CSV files (future phase).

**Constraints**:

- Configurable column mapping
- Validation before import
- German number format support

**Solution**: Import wizard with mapping configuration

**Rationale**: Many users have existing data in spreadsheets. CSV import enables migration.

### REQ-11-02: Backup Integration

**Requirement**: Automated backup functionality.

**Constraints**:

- SQLite file-based backup
- Scheduled execution
- Retention policies

**Solution**: SQLite backup command with cron/systemd timers

**Rationale**: SQLite's backup command ensures consistent backups even during writes.

## 14. Testing Requirements

### REQ-12-01: Comprehensive Test Coverage

**Requirement**: Implement comprehensive testing for all system components.

**Constraints**:

- Property-based tests for amount calculations
- Golden file tests for report outputs
- LiveView interaction tests
- Database constraint tests

**Solution**: ExUnit with property testing and golden files

**Rationale**: Financial systems require high confidence. Property tests catch edge cases, golden files ensure report consistency.

### Test Categories

1. **Unit Tests**: Pure functions, especially Amount calculations
2. **Integration Tests**: Database operations, Ecto schemas
3. **Property Tests**: Amount distribution, rounding behavior
4. **LiveView Tests**: UI interactions, form validation
5. **Golden File Tests**: Report outputs, export formats

### REQ-12-02: Test Data Management

**Requirement**: Consistent test data for development and testing.

**Constraints**:

- Reproducible test scenarios
- German-language test data
- Realistic account hierarchies

**Solution**: Seed data scripts with realistic German bookkeeping scenarios

**Rationale**: Consistent test data enables reliable testing and demonstrations.

## 15. Amount and Precision Requirements

### REQ-13-01: Amount Storage and Precision

**Requirement**: Precise financial calculations without rounding errors.

**Constraints**:

- Fixed 2-decimal precision for EUR
- No floating-point arithmetic
- Consistent rounding rules

**Solution**: Scaled integer storage (cents), banker's rounding for divisions

**Rationale**: Storing amounts as integers eliminates floating-point errors. Banker's rounding ensures fair distribution.

### REQ-13-02: Custom Ecto Type for Amount

**Requirement**: Database storage of Amount values through custom Ecto type.

**Constraints**:

- Seamless conversion between Amount structs and database
- Store as map with cents and currency fields
- Handle casting from various input formats
- Maintain type safety throughout application

**Solution**: Custom Ecto type (Ledger.EctoTypes.Amount) with cast/load/dump functions

**Rationale**: Custom types ensure Amount values are properly handled at all layers. This prevents accidental precision loss and maintains consistency between application and database representations.

### REQ-13-03: Amount Distribution

**Requirement**: Fair distribution when splitting amounts.

**Constraints**:

- Sum of parts must equal original
- No loss of cents
- Predictable distribution

**Solution**: Distribution function that adds remainder to last position

**Rationale**: Common pattern in financial systems. Adding remainder to last position is simple and predictable.

## 16. Summary

This specification defines a focused, well-architected bookkeeping system that:

1. **Leverages Elixir's strengths** - Fault tolerance, functional programming
2. **Keeps things simple** - SQLite, no JavaScript frameworks, flat design
3. **Respects accounting principles** - Simplified ledger style, flexible account structures
4. **Serves German users** - German UI, tax tracking, standard reports
5. **Enables learning** - Clean code, good documentation, standard patterns
6. **Future-proof architecture** - Built-in auth designed for extraction to SSO service

The design decisions prioritize simplicity, correctness, and maintainability over features that would complicate the system without adding essential value. The authentication design allows for future migration to a centralized service.
