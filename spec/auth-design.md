# Tideland Ledger - Authentication Design

## Overview

This document describes the authentication and authorization system for Tideland Ledger. The system provides a complete, self-contained authentication solution within the application.

## Design Principles

1. **Self-Contained**: All authentication logic is contained within the application
2. **Security-First**: Follow OWASP guidelines and Elixir/Phoenix best practices
3. **Simple Architecture**: Clean, maintainable authentication without external dependencies
4. **Role-Based Access**: Three fixed roles with clear permission boundaries

## Architecture

### Authentication Context Structure

```
lib/ledger/auth/
├── auth.ex              # Public API (context)
├── user.ex              # User schema
├── credential.ex        # Password/auth credentials
├── session.ex           # Session management
├── token.ex             # Token generation/validation
└── permissions.ex       # Role-based permissions

lib/ledger_web/auth/
├── auth_plug.ex         # Authentication plug
├── require_auth.ex      # Authorization plug
├── session_controller.ex # Login/logout endpoints
└── user_controller.ex   # User management (admin only)
```

## User Model

### Schema Design

```elixir
schema "users" do
  field :username, :string
  field :email, :string
  field :role, Ecto.Enum, values: [:admin, :bookkeeper, :viewer]
  field :active, :boolean, default: true
  field :last_login_at, :utc_datetime

  # Virtual fields for authentication
  field :password, :string, virtual: true
  field :password_confirmation, :string, virtual: true

  # Separate credential record for security
  has_one :credential, Credential

  # Audit fields
  timestamps(type: :utc_datetime)
end
```

### Credential Schema

```elixir
schema "credentials" do
  field :password_hash, :string
  field :failed_attempts, :integer, default: 0
  field :locked_until, :utc_datetime

  belongs_to :user, User

  timestamps(type: :utc_datetime)
end
```

## Authentication Flow

### 1. Login Process

```
User submits credentials
    ↓
Validate username/password
    ↓
Check account status (active, not locked)
    ↓
Generate session token
    ↓
Store session in database
    ↓
Set secure session cookie
```

### 2. Request Authentication

```
Request arrives with session cookie
    ↓
AuthPlug validates token
    ↓
Load user from database
    ↓
Inject current_user into conn
    ↓
Continue to authorization
```

### 3. Authorization

```
RequireAuth plug checks role
    ↓
Compare required role vs user role
    ↓
Allow or redirect to unauthorized
```

## Role Permissions

### Permission Matrix

| Action               | Admin | Bookkeeper | Viewer |
| -------------------- | ----- | ---------- | ------ |
| View accounts        | ✓     | ✓          | ✓      |
| Create accounts      | ✓     | ✗          | ✗      |
| View transactions    | ✓     | ✓          | ✓      |
| Create transactions  | ✓     | ✓          | ✗      |
| Post transactions    | ✓     | ✓          | ✗      |
| Void transactions    | ✓     | ✓          | ✗      |
| View reports         | ✓     | ✓          | ✓      |
| Manage users         | ✓     | ✗          | ✗      |
| Close periods        | ✓     | ✗          | ✗      |
| System configuration | ✓     | ✗          | ✗      |

## Security Measures

### Password Security

- Minimum 12 characters
- Hashed with Argon2 (preferred) or bcrypt
- Configurable complexity requirements
- Password history to prevent reuse

### Session Security

- Cryptographically secure tokens (128 bits)
- HttpOnly, Secure, SameSite cookies
- Configurable session timeout (default: 30 minutes)
- Sliding expiration with activity
- Single session per user (optional)

### Account Security

- Account lockout after failed attempts (default: 5)
- Lockout duration (default: 15 minutes)
- Audit log for security events
- Force password change on first login

## Implementation Strategy

### Built-in Authentication

```elixir
defmodule Ledger.Auth do
  def authenticate_user(username, password) do
    # Direct database authentication with secure password verification
    case get_user_by_username(username) do
      nil -> {:error, :invalid_credentials}
      user -> verify_password(password, user.password_hash)
    end
  end

  def create_session(user) do
    # Secure session token generation and storage
    token = generate_secure_token()
    create_session_record(user, token)
    {:ok, token}
  end

  def verify_session(token) do
    # Session validation and user loading
    case get_session_by_token(token) do
      nil -> {:error, :invalid_session}
      session -> {:ok, load_user(session.user_id)}
    end
  end
end
```

## Initial Setup

### Admin Bootstrap

On first application start:

```elixir
# Check if any users exist
if Ledger.Auth.count_users() == 0 do
  # Create initial admin user
  Ledger.Auth.create_user!(%{
    username: "admin",
    email: "admin@localhost",
    role: :admin,
    password: generate_initial_password()
  })

  # Log initial password for admin
  Logger.info("Initial admin password: #{initial_password}")

  # Force password change on first login
  Ledger.Auth.require_password_change("admin")
end
```

## Database Schema

### Users Table

```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    email TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('admin', 'bookkeeper', 'viewer')),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at DATETIME,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
```

### Credentials Table

```sql
CREATE TABLE credentials (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    failed_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until DATETIME,
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_credentials_user_id ON credentials(user_id);
```

### Sessions Table

```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,  -- UUID token
    user_id INTEGER NOT NULL,
    expires_at DATETIME NOT NULL,
    ip_address TEXT,
    user_agent TEXT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_activity_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);
```

## Configuration

```toml
[auth]
# Password requirements
password_min_length = 12
password_require_uppercase = true
password_require_lowercase = true
password_require_numbers = true
password_require_special = false

# Session configuration
session_timeout_minutes = 30
session_sliding_expiration = true
session_single_per_user = false

# Security settings
max_failed_attempts = 5
lockout_duration_minutes = 15
force_password_change_on_first_login = true

# Hashing algorithm: "argon2" or "bcrypt"
password_algorithm = "argon2"
```

## Testing Strategy

### Unit Tests

- Password hashing and verification
- Session token generation and validation
- Permission checks for each role
- Account lockout logic

### Integration Tests

- Full login/logout flow
- Session expiration
- Authorization for each controller action
- Password change flow

### Security Tests

- SQL injection attempts
- Session hijacking prevention
- CSRF protection
- Timing attack resistance

## Future Considerations

### Enhanced Security Features

Additional security features that could be added:

- Two-factor authentication (TOTP)
- API key management for programmatic access
- Enhanced session management with Redis
- Advanced audit logging and alerting

### Audit Requirements

All authentication events should be logged:

- Successful logins
- Failed login attempts
- Password changes
- Account lockouts
- Permission denials
- Session terminations

## Implementation Checklist

- [ ] User and Credential schemas
- [ ] Password hashing module
- [ ] Session management
- [ ] Authentication context
- [ ] Login/logout controllers
- [ ] Authentication plugs
- [ ] User management UI (admin)
- [ ] Password change functionality
- [ ] Account lockout mechanism
- [ ] Security event logging
- [ ] Initial admin creation
- [ ] Session cleanup job
- [ ] Tests for all components
- [ ] Security documentation
- [ ] Production deployment guide
