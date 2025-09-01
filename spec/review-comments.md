# Review Comments - Tideland Ledger

## Overview

This document addresses the external review feedback received for the Tideland Ledger specification. Each section corresponds to the reviewer's points, with our responses and action items.

## Positive Remarks Acknowledgment

The reviewer correctly identified our key design principles:

- Clear separation of concerns across documentation
- Coherent scope with simplified ledger approach
- Thoughtful evolution through iterative refinement
- Deep persistence design with proper constraints
- Explicit UX focus using LiveView

## Responses to Suggestions

### 1. Make the spec navigable

**Action**: Add table of contents and reading guide to spec.md

- Will add TOC at the beginning
- Include "How to read this spec" section
- Cross-reference related design documents

### 2. Freeze core domain language

**Action**: Create canonical glossary with EN/DE mappings

- Core terms: Account (Konto), Entry (Buchung), Posting (Position), Balance (Saldo), Template (Vorlage)
- Ensure consistency across all documents
- Add glossary.md to spec folder

### 3. Ledger model: define invariants

**Action**: Document core accounting invariants explicitly

- Entry balance requirement (sum of all positions = 0) - This applies to our simplified ledger system
- For simplified ledger: Each entry must have at least 2 positions that balance to zero
- Report consistency rules
- Sign conventions for different account types

### 4. DSL: lock down minimal core

**Action**: Define minimal DSL constructs in dsl-design.md

- Account hierarchy using " : " separator
- Entry structure: date, description, amount, account
- Add canonical examples: salary, groceries, rent, transfer, loan payment, tax

### 5. Amount and precision policy

**Action**: Document in spec.md and persistence-design.md

- Use scaled integer storage (cents/minor units)
- Fixed 2-decimal precision for EUR
- Banker's rounding for divisions
- Distribution function for splitting amounts fairly
- No foreign currency support in v1

### 6. Audit and immutability

**Action**: Define audit strategy

- Entries are immutable once posted
- Corrections via reversal entries only
- Consider append-only event log for full audit trail
- Document in persistence-design.md

### 7. Templates and recurrence

**Action**: Clarify template scope in spec.md

- Templates are versioned (starting at v1)
- Templates cannot be deleted or modified, only new versions created
- Preview functionality before posting
- No automatic recurrence in v1

### 8. Reporting contract

**Action**: Define reporting specification

- Input: date range, account filters, grouping options
- Output: standardized report formats
- Use recompute approach initially (no materialized views)
- Document in new reporting-design.md

### 9. Roles and permissions

**Action**: Expand permission model beyond CRUD

- Admin: all operations including period closing bypass
- Bookkeeper: post, reverse entries within open periods
- Viewer: read-only access to all reports
- Document in spec.md security section

### 10. Deployment and configuration

**Action**: Create deployment-design.md

- Environment configuration matrix
- TOML-based configuration
- SQLite to PostgreSQL migration path
- Seed data for demo/testing

### 11. Testing strategy

**Action**: Add testing section to spec.md

- Property tests for amount calculations
- Golden files for report outputs
- Constraint validation tests
- LiveView interaction tests

### 12. Performance guardrails

**Action**: Document in persistence-design.md

- Define required indexes for common queries
- Pagination strategy for large datasets
- SQLite PRAGMA settings (WAL mode, synchronous)
- VACUUM scheduling recommendations

## Answers to Open Questions

### 1. Account typing philosophy

**Answer**: Pure name-driven approach. Account names will be normalized to uppercase for consistency. The separator " : " will be normalized (no bare colons, no multiple spaces).

### 2. Single or multi-currency

**Answer**: Single currency only (EUR). Multi-tenant users must install separate instances.

### 3. Period closing

**Answer**: Yes, implement monthly/quarterly/yearly closing with locks. Only reversals allowed after closing.

### 4. Attachments/vouchers

**Answer**: Only named references to external documents, no file storage or scanning functionality.

### 5. Template versioning

**Answer**: Templates are immutable with versions starting at v1. Changes require creating new versions. Old entries retain reference to their template version.

### 6. Event model

**Recommendation**: Implement append-only audit log table alongside main tables. Main tables are canonical, audit log provides history and compliance trail.

### 7. Authorization and audit

**Answer**: Audit logs track user identity (not devices). Admins can bypass period locks with audit trail entry.

### 8. Import/export

**Answer**: Yes, CSV/JSON support planned. Create impexp-design.md to specify idempotency rules and format specifications.

### 9. Reporting cut-offs

**Answer**: Reports support "as-of" dates. Backdated entries allowed within open periods only.

### 10. SQLite durability

**Recommendation**:

- Enable WAL mode: `PRAGMA journal_mode = WAL`
- Set synchronous to NORMAL: `PRAGMA synchronous = NORMAL`
- Document backup strategy using SQLite backup API
- Add to persistence-design.md

## Quick Wins Implementation Plan

1. **Immediate** (This session):
   - Add TOC to spec.md
   - Create glossary.md
   - Update persistence-design.md with constraints and indexes
   - Add LiveView state charts to wui-design.md
   - Add canonical examples to dsl-design.md

2. **Next Phase**:
   - Create reporting-design.md
   - Create deployment-design.md
   - Create impexp-design.md
   - Expand testing strategy section

## Key Design Decisions from Review

1. **Simplified Ledger Confirmation**: We're implementing a simplified ledger style (not traditional double-entry with debit/credit), but entries still need at least 2 positions that balance to zero
2. **Immutability**: Core principle - posted entries cannot be modified
3. **Period Closing**: Implement with admin bypass capability
4. **Template Versioning**: Critical for reproducibility
5. **Audit Trail**: Implement as separate append-only table

## Next Steps

1. Update existing design documents based on this review
2. Create missing design documents (reporting, deployment, import/export)
3. Implement quick wins listed above
4. Review updated documentation for consistency

## Summary of Changes Implemented

Based on the external review, the following changes have been completed:

### 1. Documentation Updates

- **spec.md**: Added table of contents, reading guide, testing strategy section, and amount precision policy
- **requirements.md**: Updated to reflect simplified ledger style (not double-entry), hierarchical accounts with colon separators, SQLite with PostgreSQL extensibility, and semantic documentation requirements
- **README.md**: Updated to match the simplified ledger approach
- **glossary.md**: Created with canonical EN/DE terminology mappings

### 2. Design Document Enhancements

- **persistence-design.md**: Added SQLite durability settings (WAL mode, PRAGMA settings), backup strategy, performance indexes, and audit log table
- **wui-design.md**: Added LiveView state charts for entry creation workflow and form validation flows
- **dsl-design.md**: Added canonical examples for common transactions (salary, groceries, rent, transfer, loan, tax)
- **impexp-design.md**: Created comprehensive import/export specification with CSV/JSON formats, idempotency rules, and mapping interface

### 3. Key Design Clarifications

- **Account System**: Pure name-driven with uppercase normalization, hierarchical using " : " separator
- **Currency**: Single currency (EUR) only
- **Period Closing**: Monthly/quarterly/yearly locks with admin bypass
- **Templates**: Immutable with versioning starting at v1
- **Audit Trail**: Separate append-only audit log table
- **Database**: SQLite with design supporting future PostgreSQL migration

### 4. Removed References

- All mentions of "T-Systems" replaced with "Tideland"
- All references to SKR03/SKR04 removed from documentation
- Updated from double-entry to simplified ledger style throughout

These changes address all quick wins and most suggestions from the review, providing a solid foundation for implementation.
