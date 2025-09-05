defmodule Ledger.Auth do
  @moduledoc """
  The authentication and authorization context.

  This module provides the public API for all authentication-related operations
  including user management, login/logout, session management, and role-based
  authorization. It's designed to be the single interface for authentication,
  making future migration to an external auth service easier.

  The Auth context encapsulates all security-related business logic and ensures
  consistent security policies across the application.
  """

  import Ecto.Query
  alias Ecto.Multi

  alias Ledger.Repo
  alias Ledger.Auth.{User, Credential, Session}

  # User Management
  # These functions handle user creation, updates, and queries

  @doc """
  Creates a new user with the given attributes.

  This creates both the user record and the associated credential record
  in a transaction. The password is hashed before storage. Only administrators
  can create new users.

  ## Examples

      iex> create_user(%{
      ...>   username: "jdoe",
      ...>   email: "jdoe@example.com",
      ...>   password: "SecurePass123",
      ...>   password_confirmation: "SecurePass123",
      ...>   role: :bookkeeper
      ...> })
      {:ok, %User{}}

      iex> create_user(%{username: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def create_user(attrs \\ %{}) do
    Multi.new()
    |> Multi.insert(:user, User.creation_changeset(%User{}, attrs))
    |> Multi.insert(:credential, fn %{user: user} ->
      %Credential{user_id: user.id}
      |> Credential.changeset(Map.put(attrs, :user_id, user.id))
    end)
    |> Multi.run(:force_password_change, fn _repo, %{credential: credential} ->
      if Ledger.Config.force_password_change_on_first_login?() do
        credential
        |> Credential.require_password_change()
        |> Repo.update()
      else
        {:ok, credential}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, Repo.preload(user, :credential)}
      {:error, :user, changeset, _} -> {:error, changeset}
      {:error, :credential, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Updates a user's profile information.

  This only updates non-sensitive fields like email. Password changes
  and role changes use separate functions for security auditing.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Changes a user's password.

  Validates the new password against security requirements and updates
  the credential record. Clears any password change requirements and
  failed login attempts.

  ## Examples

      iex> change_user_password(user, %{
      ...>   password: "NewSecurePass123",
      ...>   password_confirmation: "NewSecurePass123"
      ...> })
      {:ok, %User{}}
  """
  def change_user_password(%User{} = user, attrs) do
    user = Repo.preload(user, :credential)

    Multi.new()
    |> Multi.update(:user, User.password_changeset(user, attrs))
    |> Multi.update(:credential, fn %{user: _} ->
      password = attrs["password"] || attrs[:password]
      Credential.password_changeset(user.credential, password)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
      {:error, :credential, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Changes a user's role.

  Only administrators can change user roles. This is a sensitive operation
  that should be logged for audit purposes.
  """
  def change_user_role(%User{} = user, new_role)
      when new_role in [:admin, :bookkeeper, :viewer] do
    user
    |> User.role_changeset(%{role: new_role})
    |> Repo.update()
  end

  @doc """
  Activates or deactivates a user.

  Deactivated users cannot log in but their data remains in the system.
  Only administrators can change user activation status.
  """
  def set_user_active(%User{} = user, active) when is_boolean(active) do
    user
    |> User.activation_changeset(%{active: active})
    |> Repo.update()
  end

  @doc """
  Lists all users with optional filters.

  ## Options

    * `:role` - Filter by user role
    * `:active` - Filter by active status
    * `:search` - Search in username and email
    * `:order_by` - Sort field (default: :username)
    * `:preload` - Associations to preload

  ## Examples

      iex> list_users(role: :bookkeeper, active: true)
      [%User{}, ...]
  """
  def list_users(opts \\ []) do
    query = from(u in User)

    query
    |> filter_users_by_role(opts[:role])
    |> filter_users_by_active(opts[:active])
    |> filter_users_by_search(opts[:search])
    |> order_users_by(opts[:order_by] || :username)
    |> maybe_preload(opts[:preload])
    |> Repo.all()
  end

  @doc """
  Gets a single user by ID.

  Returns nil if the user does not exist.
  """
  def get_user(id, opts \\ []) do
    User
    |> where(id: ^id)
    |> maybe_preload(opts[:preload])
    |> Repo.one()
  end

  @doc """
  Gets a single user by username.

  Returns nil if the user does not exist.
  """
  def get_user_by_username(username, opts \\ []) do
    User
    |> where(username: ^username)
    |> maybe_preload(opts[:preload])
    |> Repo.one()
  end

  @doc """
  Counts the total number of users.

  Used during initial setup to check if admin user needs to be created.
  """
  def count_users do
    Repo.aggregate(User, :count)
  end

  # Authentication
  # These functions handle login, logout, and session management

  @doc """
  Authenticates a user with username and password.

  Checks credentials, account status, and lockout status. Creates a new
  session on successful authentication. Records failed attempts for security.

  ## Examples

      iex> authenticate_user("admin", "correct_password", %{
      ...>   ip_address: "127.0.0.1",
      ...>   user_agent: "Mozilla/5.0..."
      ...> })
      {:ok, %Session{}}

      iex> authenticate_user("admin", "wrong_password", %{})
      {:error, :invalid_credentials}
  """
  def authenticate_user(username, password, session_attrs \\ %{}) do
    with {:ok, user} <- find_active_user(username),
         {:ok, credential} <- check_credential(user, password),
         :ok <- check_lockout(credential),
         {:ok, session} <- create_session(user, session_attrs),
         {:ok, _user} <- update_last_login(user),
         {:ok, _credential} <- clear_failed_attempts(credential) do
      {:ok, session}
    else
      {:error, :not_found} ->
        # Prevent timing attacks by doing a dummy password check
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}

      {:error, :invalid_password, credential} ->
        # Record failed attempt
        Repo.update!(Credential.record_failed_attempt(credential))
        {:error, :invalid_credentials}

      {:error, :locked, _seconds} ->
        {:error, :account_locked}

      error ->
        error
    end
  end

  @doc """
  Creates a new session for a user.

  Used internally by authenticate_user and can be used for impersonation
  by admins (with proper audit logging).
  """
  def create_session(%User{} = user, attrs \\ %{}) do
    if Ledger.Config.session_single_per_user?() do
      # Invalidate existing sessions for this user
      invalidate_user_sessions(user.id)
    end

    %Credential{}
    |> Session.create_changeset(user.id, attrs)
    |> Repo.insert()
    |> case do
      {:ok, session} -> {:ok, Repo.preload(session, :user)}
      error -> error
    end
  end

  @doc """
  Validates a session token and returns the associated session.

  Checks token format, expiration, and user status. Updates activity
  timestamp if sliding expiration is enabled.

  ## Examples

      iex> validate_session_token("valid_token_here")
      {:ok, %Session{}}

      iex> validate_session_token("expired_token")
      {:error, :invalid_session}
  """
  def validate_session_token(token) do
    if Session.valid_token_format?(token) do
      case get_valid_session(token) do
        nil ->
          {:error, :invalid_session}

        %Session{user: %User{active: false}} ->
          {:error, :user_inactive}

        session ->
          # Touch session for sliding expiration
          if Session.needs_refresh?(session) do
            {:ok, session} = touch_session(session)
            {:ok, session}
          else
            {:ok, session}
          end
      end
    else
      {:error, :invalid_session}
    end
  end

  @doc """
  Invalidates a session (logout).

  Deletes the session from the database, effectively logging out the user.
  """
  def invalidate_session(token) when is_binary(token) do
    case Repo.get(Session, token) do
      nil -> {:ok, :already_invalid}
      session -> Repo.delete(session)
    end
  end

  @doc """
  Invalidates all sessions for a user.

  Used when a user changes their password or when single session per user
  is enforced.
  """
  def invalidate_user_sessions(user_id) do
    from(s in Session, where: s.user_id == ^user_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Cleans up expired sessions.

  This should be called periodically by a background job to remove old
  sessions from the database.
  """
  def cleanup_expired_sessions do
    {count, _} = Session.expired_sessions_query() |> Repo.delete_all()
    {:ok, count}
  end

  # Authorization
  # These functions check permissions based on user roles

  @doc """
  Checks if a user can perform a specific action.

  This is the main authorization function used throughout the application.
  It implements the role-based permission matrix.

  ## Examples

      iex> can?(admin_user, :manage_users)
      true

      iex> can?(viewer_user, :create_entry)
      false
  """
  def can?(%User{} = user, action) do
    User.can?(user, action)
  end

  def can?(nil, _action), do: false

  @doc """
  Checks if a user has a specific role or higher.

  Role hierarchy: admin > bookkeeper > viewer
  """
  def has_role?(%User{role: :admin}, _role), do: true
  def has_role?(%User{role: :bookkeeper}, role) when role in [:bookkeeper, :viewer], do: true
  def has_role?(%User{role: :viewer}, :viewer), do: true
  def has_role?(%User{}, _role), do: false
  def has_role?(nil, _role), do: false

  # Initial Setup
  # Functions for bootstrapping the system

  @doc """
  Creates the initial admin user if no users exist.

  Called during application startup. Generates a random password if none
  is configured. The password is logged for the administrator to retrieve.
  """
  def ensure_admin_user_exists do
    if count_users() == 0 do
      password = Ledger.Config.admin_password() || generate_initial_password()

      attrs = %{
        username: "admin",
        email: "admin@localhost",
        role: :admin,
        password: password,
        password_confirmation: password
      }

      case create_user(attrs) do
        {:ok, user} ->
          require Logger

          Logger.info("""
          ========================================
          Initial admin user created:
          Username: admin
          Password: #{password}
          Please change this password immediately!
          ========================================
          """)

          {:ok, user}

        error ->
          error
      end
    else
      {:ok, :already_exists}
    end
  end

  # Private functions
  # Internal helpers for authentication and queries

  defp find_active_user(username) do
    case get_user_by_username(username, preload: :credential) do
      %User{active: true} = user -> {:ok, user}
      %User{active: false} -> {:error, :user_inactive}
      nil -> {:error, :not_found}
    end
  end

  defp check_credential(%User{credential: credential}, password) do
    cond do
      is_nil(credential) ->
        {:error, :not_found}

      Credential.valid_password?(credential, password) ->
        {:ok, credential}

      true ->
        {:error, :invalid_password, credential}
    end
  end

  defp check_lockout(%Credential{} = credential) do
    if Credential.locked?(credential) do
      seconds = Credential.seconds_until_unlock(credential)
      {:error, :locked, seconds}
    else
      :ok
    end
  end

  defp update_last_login(%User{} = user) do
    user
    |> User.login_changeset()
    |> Repo.update()
  end

  defp clear_failed_attempts(%Credential{} = credential) do
    credential
    |> Credential.clear_failed_attempts()
    |> Repo.update()
  end

  defp get_valid_session(token) do
    Session.get_valid_session_query(token)
    |> Repo.one()
  end

  defp touch_session(%Session{} = session) do
    session
    |> Session.touch_changeset()
    |> Repo.update()
  end

  defp generate_initial_password do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
    |> String.downcase()
  end

  # Query helpers
  # Build composable queries

  defp filter_users_by_role(query, nil), do: query
  defp filter_users_by_role(query, role), do: where(query, [u], u.role == ^role)

  defp filter_users_by_active(query, nil), do: query
  defp filter_users_by_active(query, active), do: where(query, [u], u.active == ^active)

  defp filter_users_by_search(query, nil), do: query
  defp filter_users_by_search(query, ""), do: query

  defp filter_users_by_search(query, search_term) do
    search_pattern = "%#{search_term}%"

    where(
      query,
      [u],
      ilike(u.username, ^search_pattern) or ilike(u.email, ^search_pattern)
    )
  end

  defp order_users_by(query, :username), do: order_by(query, [u], asc: u.username)
  defp order_users_by(query, :email), do: order_by(query, [u], asc: u.email)
  defp order_users_by(query, :role), do: order_by(query, [u], asc: u.role, asc: u.username)
  defp order_users_by(query, :created_at), do: order_by(query, [u], desc: u.inserted_at)
  defp order_users_by(query, _), do: order_users_by(query, :username)

  defp maybe_preload(query, nil), do: query
  defp maybe_preload(query, []), do: query
  defp maybe_preload(query, preloads), do: preload(query, ^preloads)
end
