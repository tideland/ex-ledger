# Tideland Ledger

A web-based simplified ledger-style bookkeeping system implemented in Elixir, designed for learning and practical use.

## Overview

Tideland Ledger is a comprehensive accounting system that provides:

- Simplified ledger-style bookkeeping with transaction validation
- Multi-user support with role-based access control (Admin, Bookkeeper, Viewer)
- Hierarchical chart of accounts management with colon-separated levels
- Transaction templates for recurring entries
- Financial reporting including balance sheets
- German language UI with English documentation
- Clean, maintainable codebase suitable for learning Elixir

## Technology Stack

- **Elixir** with **Phoenix Framework** for the web application
- **Ecto** ORM with **SQLite** for data persistence (designed for future PostgreSQL support)
- **Phoenix LiveView** for interactive UI components
- **Tailwind CSS** for styling
- **Tideland Auth** for authentication and authorization

## Project Structure

```
ledger/
├── config/           # Configuration files
├── lib/             # Application source code
│   ├── ledger/      # Business logic and contexts
│   └── ledger_web/  # Web interface (controllers, views, templates)
├── priv/            # Static assets and resources
│   ├── repo/        # Database migrations and seeds
│   └── static/      # CSS, JavaScript, images
├── test/            # Test files
├── doc/             # Documentation
│   └── requirements.md
└── mix.exs          # Project definition and dependencies
```

## Features

### Core Functionality

- **Account Management**: Maintain hierarchical chart of accounts using colon separators (e.g., "Einnahmen : Arbeit : Tideland")
- **Transaction Entry**: Create and post journal entries with validation
- **Templates**: Define and use templates for recurring transactions
- **Reporting**: Generate balance sheets and account reports
- **Audit Trail**: Complete history of all transactions and changes

### Security

- Authentication via Tideland Auth service
- Role-based permissions:
  - **Admin**: Full system access, user management
  - **Bookkeeper**: Create and manage transactions
  - **Viewer**: Read-only access to reports
- Secure session management
- Audit logging for sensitive operations

### Technical Features

- Custom Amount type for precise financial calculations
- Configurable precision and rounding behavior
- Distribution functions for splitting amounts
- TOML-based configuration
- Comprehensive test coverage
- Clean separation of concerns

## Getting Started

### Prerequisites

- Elixir 1.15 or later
- Erlang/OTP 26 or later
- SQLite 3
- Git

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/tideland/ex-ledger.git
   cd ex-ledger
   ```

2. Install dependencies:

   ```bash
   mix deps.get
   ```

3. Create and migrate the database:

   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

4. Configure the application:

   ```bash
   cp config/config.example.toml config/config.toml
   # Edit config/config.toml with your settings
   ```

5. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

### Development Setup

1. Install development dependencies:

   ```bash
   mix deps.get
   mix compile
   ```

2. Run tests:

   ```bash
   mix test
   ```

3. Run the linter:

   ```bash
   mix credo
   ```

4. Generate documentation:
   ```bash
   mix docs
   ```

## Configuration

The application uses TOML files for configuration. Key configuration areas include:

- Database connection settings
- Authentication service endpoint
- Application port and host
- Session configuration
- Amount precision settings

See `config/config.example.toml` for all available options.

## Usage

### First Time Setup

1. The system comes with a default `admin` user
2. Log in and create additional users as needed
3. Set up your chart of accounts
4. Define transaction templates for common entries
5. Begin recording transactions

### Daily Operations

1. **Transaction Entry**: Use templates or manual entry for journal entries
2. **Reports**: Generate balance sheets and account summaries
3. **Maintenance**: Keep chart of accounts and templates updated

## Development

### Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/ledger/accounts_test.exs
```

### Code Quality

```bash
# Run static analysis
mix credo

# Run formatter
mix format

# Check formatting
mix format --check-formatted
```

### Database Management

```bash
# Create new migration
mix ecto.gen.migration migration_name

# Run migrations
mix ecto.migrate

# Rollback migration
mix ecto.rollback

# Reset database
mix ecto.reset
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure:

- All tests pass
- Code follows the project style guide
- Documentation is updated
- Commit messages are clear and descriptive

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## Acknowledgments

- Built as a learning project for the Elixir ecosystem
- Inspired by simplified ledger-style bookkeeping principles
- Thanks to the Elixir and Phoenix communities

## Support

For questions and support:

- Open an issue on GitHub
- Check the documentation in `/doc`
- Review the test cases for usage examples

---

**Note**: This is a learning project designed to demonstrate Elixir/Phoenix best practices while building a practical application. It is suitable for small to medium-sized bookkeeping needs but should be thoroughly tested before production use.
