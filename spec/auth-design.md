# Tideland Ledger - Authentication Design

## Overview

This document describes the authentication and authorization system for Tideland Ledger. The system is designed with a dual purpose: providing immediate, fully-functional authentication while maintaining a clean architecture that allows future extraction to a centralized Tideland Auth service.

## Design Principles

1. **Extraction-Ready**: All authentication logic is isolated in dedicated modules
2. **Interface-First**: Define clear contracts between auth and business logic
3. **Security-First**: Follow OWASP guidelines and Elixir/Phoenix best practices
4. **Simple Migration**: Moving to external auth should require minimal changes

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

| Action | Admin | Bookkeeper | Viewer |
|--------|-------|------------|---------|
| View accounts | ✓ | ✓ | ✓ |
| Create accounts | ✓ | ✗ | ✗ |
| View transactions | ✓ | ✓ | ✓ |
| Create transactions | ✓ | ✓ | ✗ |
| Post transactions | ✓ | ✓ | ✗ |
| Void transactions | ✓ | ✓ | ✗ |
| View reports | ✓ | ✓ | ✓ |
| Manage users | ✓ | ✗ | ✗ |
| Close periods | ✓ | ✗ | ✗ |
| System configuration | ✓ | ✗ | ✗ |

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

## Migration Strategy

### Phase 1: Current Implementation (Built-in Auth)

```elixir
defmodule Ledger.Auth do
  def authenticate_user(username, password) do
    # Direct database authentication
  end

  def create_session(user) do
    # Local session management
  end
end
```

### Phase 2: Future External Auth

```elixir
defmodule Ledger.Auth do
  def authenticate_user(username, password) do
    # Delegate to Tideland Auth API
    TidelandAuth.authenticate(username, password)
  end

  def create_session(user) do
    # Use JWT from Tideland Auth
    TidelandAuth.create_token(user)
  end
end
```

### Migration Path

1. **Minimal Interface Changes**: Business logic calls `Auth.authenticate_user/2` regardless of implementation
2. **User Sync**: Built-in users can be exported to Tideland Auth
3. **Session Compatibility**: Design sessions to work with JWT tokens
4. **Role Mapping**: Same role names in both systems

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

### OAuth2/OIDC Support

When migrating to Tideland Auth, consider:

- OAuth2 authorization code flow
- OpenID Connect for user info
- JWT token validation
- Token refresh mechanism

### Single Sign-On (SSO)

- Shared session store (Redis)
- Cross-domain authentication
- Service-to-service authentication
- API key management

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
- [ ] Migration guide for Tideland Auth
