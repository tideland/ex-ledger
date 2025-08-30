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

## 1. Overview

This document provides a formal specification for the Tideland Ledger system, consolidating all requirements with their constraints, chosen solutions, and rationales for each decision.

## 2. Core System Requirements

### REQ-001: Programming Language and Framework

**Requirement**: The system must be implemented in Elixir using the Phoenix Framework.

**Constraints**:

- Developer is new to Elixir but experienced in other languages
- Must serve as a learning project
- Should follow Elixir/OTP best practices

**Solution**: Pure Elixir/Phoenix implementation with OTP supervision trees

**Rationale**: Elixir provides excellent fault tolerance, concurrent processing capabilities, and clean functional programming patterns ideal for financial calculations. Phoenix offers a mature web framework with LiveView for real-time UI without JavaScript complexity.

### REQ-002: Database System

**Requirement**: Use SQLite for data persistence.

**Constraints**:

- Must support ACID transactions
- Should be simple to deploy and backup
- No need for distributed database features

**Solution**: Ecto with SQLite3 adapter

**Rationale**: SQLite provides full ACID compliance, zero-configuration deployment, and simple file-based backups. Perfect for single-tenant bookkeeping systems where all data fits on one machine.

### REQ-003: User Interface Technology

**Requirement**: Web-based user interface without Node.js or complex JavaScript frameworks.

**Constraints**:

- No Node.js in the build pipeline
- Minimal client-side JavaScript
- Must provide real-time feedback for data entry

**Solution**: Phoenix LiveView with server-side rendering

**Rationale**: LiveView provides real-time interactivity through WebSockets while keeping all logic in Elixir. This eliminates JavaScript complexity while delivering modern UX. The ~29KB LiveView runtime is maintained by the Phoenix team.

### REQ-004: Configuration Management

**Requirement**: All configuration must be externalized to TOML files.

**Constraints**:

- No hardcoded configuration except roles and admin user
- Must support different deployment environments
- Configuration should be human-readable

**Solution**: TOML configuration files with custom Config.Provider

**Rationale**: TOML is more readable than JSON or YAML for configuration. It's well-supported in Elixir and allows comments. The Config.Provider pattern enables runtime configuration changes.

## 3. Authentication and Authorization Requirements

### REQ-005: Authentication Service

**Requirement**: Use external Tideland Auth service for authentication.

**Constraints**:

- Cannot implement own authentication
- Must integrate with existing auth service
- Need to map external users to local roles

**Solution**: OAuth2/JWT integration with Tideland Auth

**Rationale**: Separating authentication from the application follows security best practices and allows centralized user management across multiple Tideland applications.

### REQ-006: Authorization Roles

**Requirement**: Three hardcoded roles: Admin, Bookkeeper (Buchhalter), Viewer (Betrachter).

**Constraints**:

- Roles must be hardcoded, not configurable
- Hardcoded "admin" superuser account
- Role-based permissions for all operations

**Solution**: Hardcoded role definitions with permission matrices

**Rationale**: Fixed roles simplify the authorization model and ensure consistent permissions across deployments. The hardcoded admin account ensures system recovery options.

### REQ-007: Multi-tenancy

**Requirement**: Single-tenant system with one set of books shared by all users.

**Constraints**:

- No user-specific books
- All users see the same data (based on permissions)
- No data isolation between users

**Solution**: Single database schema without tenant isolation

**Rationale**: Simplifies the data model and matches typical small business needs where all users work on the same set of books.

## 4. Accounting Domain Requirements

### REQ-008: Double-Entry Bookkeeping

**Requirement**: Implement pure double-entry bookkeeping without enforced account types.

**Constraints**:

- Every transaction must balance (sum to zero)
- Minimum two positions per transaction
- No system-enforced account types (assets, liabilities, etc.)

**Solution**: Transaction model with positions, zero-sum validation

**Rationale**: Pure double-entry is the foundation of all accounting systems. Not enforcing account types provides flexibility for different accounting standards (SKR03, SKR04, etc.).

### REQ-009: Account Structure

**Requirement**: Hierarchical account structure without enforced types.

**Constraints**:

- Support various numbering schemes (SKR03, SKR04)
- Account meaning derived from numbering convention
- Must support parent-child relationships

**Solution**: Path-based account hierarchy (e.g., "1000 : 1200 : Bank - Checking")

**Rationale**: Path-based structure is self-documenting and eliminates the need for separate parent ID tracking. It mirrors file system paths, making it intuitive.

### REQ-010: Amount Representation

**Requirement**: Signed decimal amounts instead of separate debit/credit fields.

**Constraints**:

- Must maintain precision for currency (2 decimal places)
- Positive represents debit, negative represents credit
- Must handle distribution/splitting correctly

**Solution**: Custom Amount type based on Decimal with signed values

**Rationale**: Signed amounts simplify data entry and calculations. Users enter +1500 or -1500 instead of choosing debit/credit columns. This is more intuitive for non-accountants.

### REQ-011: Amount Distribution

**Requirement**: Correct distribution when splitting amounts (e.g., 100/3).

**Constraints**:

- Sum of distributed amounts must equal original
- Rounding must not create imbalances
- Must work for any number of splits

**Solution**: Distribution function that adds remainder to last amount

**Rationale**: Ensures transaction balance is maintained even with rounding. Example: 100/3 = [33.33, 33.33, 33.34].

### REQ-012: Transaction Templates

**Requirement**: Reusable transaction templates with fractional distribution.

**Constraints**:

- Templates must validate against existing accounts
- Support both fixed amounts and percentages
- Fractions as standard approach (not special case)

**Solution**: Template system with fraction-based position definitions

**Rationale**: Fractions/percentages are more flexible than fixed amounts. A rent template can work whether rent is 1000 or 1500 by using fractions.

### REQ-013: Tax Relevance Tracking

**Requirement**: Mark individual positions as tax-relevant.

**Constraints**:

- Must be at position level, not transaction level
- Support German tax requirements
- Example: Split craftsman invoice into deductible labor and non-deductible materials

**Solution**: Boolean tax_relevant flag on each position

**Rationale**: German tax law often requires splitting invoices. Position-level tracking provides the necessary granularity.

## 5. User Interface Requirements

### REQ-014: Language

**Requirement**: German-only user interface.

**Constraints**:

- All UI text in German
- Source code and documentation in English
- Database content in user's language (German)

**Solution**: Gettext for German translations, English variable names

**Rationale**: The application targets German users. Keeping code in English maintains compatibility with the broader Elixir ecosystem.

### REQ-015: Visual Design

**Requirement**: Simple, flat design like mainframe terminals.

**Constraints**:

- No gradients, shadows, or complex CSS
- Menu items as full clickable areas
- Minimal color usage
- No animations

**Solution**: Basic CSS with flat design, vertical navigation menu

**Rationale**: Simplicity reduces maintenance and focuses users on functionality rather than aesthetics. Terminal-like design reinforces the "tool" nature of the application.

### REQ-016: Navigation Structure

**Requirement**: Clear, flat navigation without dropdowns.

**Constraints**:

- All functions accessible within 2 clicks
- No nested menus
- Vertical menu for variable page widths

**Solution**: Fixed vertical navigation with main sections

**Rationale**: Vertical menus work better with unknown page widths and provide room for German text. Flat navigation reduces cognitive load.

## 6. Data Entry Requirements

### REQ-017: Transaction Entry

**Requirement**: Efficient transaction entry with real-time validation.

**Constraints**:

- Must show running balance
- Validate zero-sum before saving
- Support dynamic position adding/removal

**Solution**: LiveView form with real-time sum calculation

**Rationale**: Immediate feedback prevents errors. LiveView eliminates round-trips while keeping logic server-side.

### REQ-018: Account Selection

**Requirement**: Account selection supporting hierarchical paths.

**Constraints**:

- Must show full account path
- Searchable by any part of path
- Wide enough for long hierarchical names

**Solution**: Searchable dropdown showing full paths

**Rationale**: Full paths provide context. Search enables quick selection even with hundreds of accounts.

### REQ-019: Date Handling

**Requirement**: ISO 8601 date format throughout the system.

**Constraints**:

- Consistent sorting
- Unambiguous format
- International standard

**Solution**: YYYY-MM-DD format everywhere

**Rationale**: ISO 8601 eliminates ambiguity between DD/MM and MM/DD formats and sorts naturally.

## 7. Reporting Requirements

### REQ-020: Standard Reports

**Requirement**: Generate standard accounting reports.

**Constraints**:

- Trial balance (Probebilanz)
- Balance sheet (Bilanz)
- Account statements (Kontoauszug)
- Must reflect German accounting standards

**Solution**: Report modules interpreting account codes by convention

**Rationale**: Since account types aren't system-enforced, reports interpret accounts based on their codes according to the chosen numbering scheme.

### REQ-021: Export Capabilities

**Requirement**: Export reports in common formats.

**Constraints**:

- CSV for data processing
- PDF for archival (future)
- Maintain number formatting

**Solution**: Initial CSV export, PDF planned for later

**Rationale**: CSV provides immediate value for Excel users. PDF can be added when needed.

## 8. Technical Architecture Requirements

### REQ-022: Code Organization

**Requirement**: Follow Phoenix conventions with clear separation of concerns.

**Constraints**:

- Business logic separate from web layer
- Contexts for domain boundaries
- OTP supervision trees

**Solution**: Standard Phoenix structure with contexts

**Rationale**: Following conventions makes the codebase maintainable and familiar to other Elixir developers.

### REQ-023: Testing Strategy

**Requirement**: Comprehensive test coverage.

**Constraints**:

- Unit tests for business logic
- Integration tests for workflows
- Test data factories

**Solution**: ExUnit with test factories and database sandboxing

**Rationale**: Good test coverage is essential for financial software. Database sandboxing enables parallel test execution.

### REQ-024: Error Handling

**Requirement**: Graceful error handling with user-friendly messages.

**Constraints**:

- Never show technical errors to users
- Log technical details for debugging
- Provide recovery suggestions

**Solution**: Error boundary supervision, translated error messages

**Rationale**: Users need clear guidance when errors occur. Technical details belong in logs, not user interfaces.

## 9. Deployment Requirements

### REQ-025: Package Distribution

**Requirement**: Distribute as Hex package "tideland-ledger".

**Constraints**:

- Follow Elixir naming conventions
- Repository at github.com/tideland/ex-ledger
- Semantic versioning

**Solution**: Standard Hex package with mix release support

**Rationale**: Hex is the standard package manager for Elixir. The naming follows Tideland conventions.

### REQ-026: Configuration Deployment

**Requirement**: Support multiple deployment scenarios.

**Constraints**:

- Development with local files
- Production with system paths
- Docker containers

**Solution**: Configurable paths with sensible defaults

**Rationale**: Different deployment targets have different filesystem conventions. Configurability enables flexibility.

### REQ-027: Database Location

**Requirement**: Configurable SQLite database location.

**Constraints**:

- Development: local directory
- Production: system directory
- Must be backup-friendly

**Solution**: Path configuration in TOML with platform defaults

**Rationale**: SQLite databases are files, making backup simple. Platform-specific defaults follow OS conventions.

## 10. Performance Requirements

### REQ-028: Response Times

**Requirement**: Sub-second response for common operations.

**Constraints**:

- Transaction entry
- Report generation for < 10,000 transactions
- Account balance queries

**Solution**: Indexed database queries, LiveView debouncing

**Rationale**: Users expect responsive interfaces. Proper indexing and debouncing prevent performance issues.

### REQ-029: Scalability

**Requirement**: Handle thousands of transactions efficiently.

**Constraints**:

- Single SQLite database
- Limited by disk I/O
- No distributed processing

**Solution**: Pagination, efficient queries, denormalized balances

**Rationale**: SQLite can handle millions of rows. Pagination and smart queries keep the UI responsive.

## 11. Future Considerations

### REQ-030: CSV Import

**Requirement**: Import transactions from CSV files (future phase).

**Constraints**:

- Configurable column mapping
- Validation before import
- German number format support

**Solution**: Import wizard with mapping configuration

**Rationale**: Many users have existing data in spreadsheets. CSV import enables migration.

### REQ-031: Backup Integration

**Requirement**: Automated backup functionality.

**Constraints**:

- SQLite file-based backup
- Scheduled execution
- Retention policies

**Solution**: SQLite backup command with cron/systemd timers

**Rationale**: SQLite's backup command ensures consistent backups even during writes.

## 12. Summary

This specification defines a focused, well-architected bookkeeping system that:

1. **Leverages Elixir's strengths** - Fault tolerance, functional programming
2. **Keeps things simple** - SQLite, no JavaScript frameworks, flat design
3. **Respects accounting principles** - Pure double-entry, flexible account structures
4. **Serves German users** - German UI, tax tracking, standard reports
5. **Enables learning** - Clean code, good documentation, standard patterns

The design decisions prioritize simplicity, correctness, and maintainability over features that would complicate the system without adding essential value.
