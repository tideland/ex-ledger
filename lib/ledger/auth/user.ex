defmodule TidelandLedger.Auth.User do
  @moduledoc """
  User schema for authentication and authorization.

  This module defines the user structure with built-in authentication fields.
  It's designed to support both local authentication and future migration to
  an external authentication service. The schema includes role-based access
  control with three fixed roles: admin, bookkeeper, and viewer.

  Users have a separate credential record for security, keeping password
  hashes isolated from the main user data.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias TidelandLedger.Auth.{User, Credential}

  @type role :: :admin | :bookkeeper | :viewer
  @type t :: %__MODULE__{
          id: integer() | nil,
          username: String.t(),
          email: String.t(),
          role: role(),
          active: boolean(),
          last_login_at: DateTime.t() | nil,
          password: String.t() | nil,
          password_confirmation: String.t() | nil,
          credential: Credential.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @valid_roles [:admin, :bookkeeper, :viewer]
  @email_regex ~r/^[^\s]+@[^\s]+$/

  schema "users" do
    # Login credentials
    field(:username, :string)
    field(:email, :string)

    # Authorization
    field(:role, Ecto.Enum, values: @valid_roles)

    # Account status
    field(:active, :boolean, default: true)
    field(:last_login_at, :utc_datetime)

    # Virtual fields for password handling
    # These are never stored in the database
    field(:password, :string, virtual: true)
    field(:password_confirmation, :string, virtual: true)

    # Separate credential record for security isolation
    has_one(:credential, Credential)

    timestamps(type: :utc_datetime)
  end

  # Changesets
  # Different changesets for different operations ensure proper validation

  @doc """
  Changeset for creating a new user.

  Validates all required fields and ensures the password meets security
  requirements. This changeset should be used when an admin creates a new user
  or during initial system setup.
  """
  def creation_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :role, :password, :password_confirmation])
    |> validate_required([:username, :email, :role, :password])
    |> validate_username()
    |> validate_email()
    |> validate_role()
    |> validate_password()
    |> validate_confirmation(:password)
    |> unique_constraint(:username)
    |> unique_constraint(:email)
  end

  @doc """
  Changeset for updating user profile information.

  This excludes password changes and role changes, which have their own
  dedicated changesets for security reasons.
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> unique_constraint(:email)
  end

  @doc """
  Changeset for changing a user's password.

  Requires the password confirmation to match and validates the new password
  against security requirements. This is used for both user-initiated password
  changes and admin password resets.
  """
  def password_changeset(user, attrs) do
    user
    |> cast(attrs, [:password, :password_confirmation])
    |> validate_required([:password, :password_confirmation])
    |> validate_password()
    |> validate_confirmation(:password)
  end

  @doc """
  Changeset for updating role (admin only operation).

  Role changes are sensitive operations that should be logged for audit
  purposes. Only administrators can change user roles.
  """
  def role_changeset(user, attrs) do
    user
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_role()
  end

  @doc """
  Changeset for activating/deactivating a user.

  Deactivated users cannot log in but their data remains in the system
  for historical purposes. This is preferred over deletion for audit trails.
  """
  def activation_changeset(user, attrs) do
    user
    |> cast(attrs, [:active])
    |> validate_required([:active])
  end

  @doc """
  Updates the last login timestamp.

  This is called automatically during successful authentication and helps
  with security monitoring and user activity tracking.
  """
  def login_changeset(user) do
    change(user, last_login_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end

  # Validation functions
  # These ensure data integrity and security requirements

  defp validate_username(changeset) do
    changeset
    |> validate_length(:username, min: 3, max: 32)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_\-\.]+$/,
      message: "may only contain letters, numbers, underscores, hyphens, and dots"
    )
  end

  defp validate_email(changeset) do
    changeset
    |> validate_length(:email, max: 254)
    |> validate_format(:email, @email_regex, message: "must be a valid email address")
    |> update_change(:email, &String.downcase/1)
  end

  defp validate_role(changeset) do
    validate_inclusion(changeset, :role, @valid_roles)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: TidelandLedger.Config.password_min_length())
    |> validate_password_requirements()
  end

  defp validate_password_requirements(changeset) do
    password = get_change(changeset, :password)

    if password do
      changeset
      |> validate_password_requirement(
        password,
        TidelandLedger.Config.password_require_uppercase?(),
        ~r/[A-Z]/,
        "must contain at least one uppercase letter"
      )
      |> validate_password_requirement(
        password,
        TidelandLedger.Config.password_require_lowercase?(),
        ~r/[a-z]/,
        "must contain at least one lowercase letter"
      )
      |> validate_password_requirement(
        password,
        TidelandLedger.Config.password_require_numbers?(),
        ~r/[0-9]/,
        "must contain at least one number"
      )
      |> validate_password_requirement(
        password,
        TidelandLedger.Config.password_require_special?(),
        ~r/[^A-Za-z0-9]/,
        "must contain at least one special character"
      )
    else
      changeset
    end
  end

  defp validate_password_requirement(changeset, password, required?, pattern, message) do
    if required? && not String.match?(password, pattern) do
      add_error(changeset, :password, message)
    else
      changeset
    end
  end

  # Query helpers
  # These provide common query patterns for user lookups

  @doc """
  Returns a query for active users only.
  """
  def active_query do
    from(u in __MODULE__, where: u.active == true)
  end

  @doc """
  Returns a query for users with a specific role.
  """
  def by_role_query(role) when role in @valid_roles do
    from(u in __MODULE__, where: u.role == ^role)
  end

  # Helper functions
  # These provide convenient access to user properties

  @doc """
  Checks if a user has admin role.
  """
  def admin?(%User{role: :admin}), do: true
  def admin?(%User{}), do: false

  @doc """
  Checks if a user has bookkeeper role or higher.
  """
  def bookkeeper?(%User{role: role}) when role in [:admin, :bookkeeper], do: true
  def bookkeeper?(%User{}), do: false

  @doc """
  Checks if a user is active.
  """
  def active?(%User{active: true}), do: true
  def active?(%User{}), do: false

  @doc """
  Returns the display name for a user.

  Uses username as the display name. In future versions, this could
  support full names or other display preferences.
  """
  def display_name(%User{username: username}), do: username

  @doc """
  Returns a list of all valid roles.

  Useful for form selects and validation.
  """
  def valid_roles, do: @valid_roles

  @doc """
  Returns a human-readable role name in German.
  """
  def role_display(:admin), do: "Administrator"
  def role_display(:bookkeeper), do: "Buchhalter"
  def role_display(:viewer), do: "Betrachter"

  @doc """
  Checks if a user can perform an action based on their role.

  This is a simplified permission check. More complex permission logic
  should be implemented in the Auth context or a dedicated Permissions module.
  """
  def can?(%User{role: :admin}, _action), do: true

  def can?(%User{role: :bookkeeper}, action)
      when action in [:create_entry, :post_entry, :void_entry],
      do: true

  def can?(%User{role: :viewer}, action)
      when action in [:view_accounts, :view_entries, :view_reports],
      do: true

  def can?(%User{}, _action), do: false

  @doc """
  Determines if a user requires a password change.

  This is typically set for new users or after a password reset.
  The actual flag is stored in the credential record.
  """
  def requires_password_change?(%User{credential: %Credential{must_change_password: true}}),
    do: true

  def requires_password_change?(%User{}), do: false
end
