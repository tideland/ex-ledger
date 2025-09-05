# Tideland Ledger - Requirements Analysis

## 1. Project Overview

The Tideland Ledger is a web-based simplified ledger-style bookkeeping system implemented in Elixir. The primary goals are:

- Learning the Elixir language and ecosystem
- Creating a practical, maintainable ledger system
- Leveraging Phoenix for web UI and Ecto with SQLite for data persistence
- Providing excellent documentation for learning purposes

## 2. Core Functional Requirements

### 2.1 User Management

- Multi-user system using Tideland Auth service for authentication
- Three ledger-specific roles: Admin, Bookkeeper, Viewer
- Hardcoded "admin" user as system root (like Unix root)
- Admin users can create and manage other users within the ledger
- User authentication delegated to Tideland Auth
- Role-based permissions for ledger operations

### 2.2 Ledger Functionality

- Simplified ledger-style bookkeeping (not double-entry with debit/credit)
- Chart of accounts management (maintainable online)
- Hierarchical account system using colon separators
  - Accounts are strings with hierarchy indicated by colons
  - Separator normalized to " : " (space-colon-space) for readability
  - Example hierarchies: "Einnahmen : Arbeit : Tideland", "Ausgaben : Anschaffungen : Technik"
  - Full-text search capability across accounts
  - Filtering by hierarchy level
- No SKR03/SKR04 or similar chart of accounts standards
- Transaction entry and posting (internally called "Entry" with "Positions")
- Transaction templates for recurring entries (maintainable online)
- Templates must validate against existing accounts
- Template positions use fractions of total sum as standard
- Optional default totals for templates
- Journal entries with proper audit trail

### 2.3 Financial Reporting

- Trial balance generation
- Account balance queries (debit/credit totals)
- Transaction history views (based on Entry/Position model)
- Flexible reporting based on account numbering schemes
- Future: Additional reports and dashboards
- Export capabilities (format to be defined)

### 2.4 Amount Type Requirements

- Custom Amount type based on Decimal
- Fixed precision handling (configurable, default for currency)
- Special rounding behavior for divisions
- Distribution function for splitting amounts (e.g., 1/3 = [0.33, 0.33, 0.34])
- Currency-aware operations

## 3. Technical Requirements

### 3.1 Technology Stack

- Elixir with Phoenix Framework
- Ecto ORM with SQLite database
- LiveView for interactive UI components
- Tailwind CSS for styling (Phoenix default)
- Tideland Auth for authentication and authorization

### 3.2 Architecture Requirements

- Clean, maintainable code structure with clear naming
- Comprehensive documentation including semantic comments for modules, types, and functions
- Test-driven development approach
- Domain-driven design principles
- Separation of concerns (contexts, schemas, views)

### 3.3 Database Requirements

- SQLite for initial data persistence with design allowing future PostgreSQL support
- Database abstraction layer to facilitate future database system changes
- Proper schema design for simplified ledger-style bookkeeping
- Transaction integrity and ACID compliance
- Efficient indexing for reporting queries
- Migration support for schema evolution

## 4. User Interface Requirements

### 4.1 General UI Requirements

- Responsive web design
- Clean, intuitive interface
- German language UI from the beginning
- Keyboard shortcuts for power users
- Form validation and error handling

### 4.2 Key UI Components

- Dashboard with account overview
- Transaction entry forms
- Template management interface
- Report generation and viewing
- Account management screens
- User profile and settings

## 5. Non-Functional Requirements

### 5.1 Performance

- Fast transaction posting
- Efficient report generation
- Responsive UI with sub-second page loads
- Scalable to thousands of transactions

### 5.2 Security

- Authentication via Tideland Auth service
- Role-based authorization for ledger operations
- Audit logging for sensitive operations
- Protection against common web vulnerabilities

### 5.3 Maintainability

- Comprehensive code documentation
- Clear module structure
- Consistent coding standards
- Automated testing suite
- Development and deployment documentation

### 4.4 Usability

- Intuitive workflow for common tasks
- Clear error messages
- Contextual help where needed
- Consistent UI patterns

### 4.5 Internationalization

- Business logic returns error atoms/symbols, not translated strings
- Translation happens only at the UI layer
- German language UI with potential for future language additions
- Separation of concerns between business logic and presentation

## 6. Development Priorities

### Phase 1: Foundation

1. Project setup and structure
2. Integration with Tideland Auth service
3. Basic account and transaction models with hierarchical support
4. Amount type implementation
5. Simple transaction entry

### Phase 2: Core Features

1. Transaction validation for ledger style
2. Transaction templates
3. Basic reports and account summaries
4. Account management UI with hierarchy navigation
5. Transaction history views

### Phase 3: Enhanced Features

1. Advanced reporting
2. Dashboard implementation
3. Bulk operations
4. Export functionality

## 7. Open Questions and Considerations

### 7.1 User Management

- **User roles**: Admin, Bookkeeper, Viewer (confirmed)
- **Separate books per user**: No - single set of books shared by all users
- **Multi-tenancy**: No - single tenant system

### 7.2 Accounting Standards

- **Accounting principles**: Simplified ledger-style bookkeeping
  - No double-entry with debit/credit
  - No SKR03, SKR04 or similar chart of accounts standards
  - Hierarchical account structure using colon separators
  - Account meaning determined by hierarchy and naming
- **German bookkeeping**: Yes - system designed for German use
- **Tax reporting**: Individual positions must be markable as tax-relevant
  - Example: When splitting invoices, distinguish between tax-deductible services (craftsmen) and materials
  - Tax relevance flag needed at position level, not just transaction level

### 7.3 Integration

- **Import capabilities**: Yes - CSV import planned for later phase
- **API for external integrations**: No
- **Backup and restore functionality**: Yes - required

### 7.4 Amount Type Design

- **Multiple currencies**: No - single currency only
- **Exchange rate management**: Not needed
- **Historical rate tracking**: Not needed

## 8. Success Criteria

- Functional simplified ledger-style bookkeeping system
- Clean, well-documented codebase with semantic comments
- Comprehensive test coverage
- Intuitive user interface
- Efficient performance for typical use cases
- Learning resource for Elixir development

## 9. Constraints and Assumptions

- SQLite database initially with design supporting future PostgreSQL migration
- Web-based only (no mobile app)
- Modern browser support only
- Development by experienced programmer new to Elixir
- Focus on learning and maintainability over premature optimization
- Configuration via external TOML files
- Designed as reusable product for others
- Authentication handled by external Tideland Auth service

## 10. Future Considerations

- Mobile responsive design
- API for third-party integrations
- Advanced reporting and analytics
- Multi-currency support
- Automated reconciliation features
- Budgeting and forecasting modules

## 11. Configuration Requirements

- All configuration externalized to TOML files
- No hardcoded settings except roles and admin user
- Database connection settings
- Application settings (port, host, etc.)
- Configurable for different deployments

## 12. Deployment Requirements

- Repository: https://github.com/tideland/ex-ledger
- Package name for Hex: tideland-ledger
- Must follow Elixir/OTP deployment standards
- Support for releases via Mix
- Configuration through environment and TOML files

## 13. UI Technology Constraints

- No Node.js or complex JavaScript frameworks
- Pure Elixir/Phoenix with server-side rendering
- Simple, flat design like mainframe terminals
- Menu items as flat buttons (clickable anywhere)
- Minimal external CSS for color customization only
- No complex styling or animations
- Focus on functionality over aesthetics
- UI text in German language only
- Source code, SQL, comments, and documentation remain in English
- Error handling: Business logic returns atoms, UI layer translates to German
