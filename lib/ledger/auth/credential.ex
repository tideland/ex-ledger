defmodule TidelandLedger.Auth.Credential do
  @moduledoc """
  Credential schema for secure password storage.

  This schema is separated from the User schema for security reasons. It contains
  sensitive authentication data like password hashes and tracks authentication
  failures for account lockout functionality. The separation ensures that password
  hashes are never accidentally exposed in user queries or APIs.

  The credential system supports configurable password hashing algorithms (Argon2
  or bcrypt) and implements account lockout after failed login attempts.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TidelandLedger.Auth.{User, Credential}

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer(),
          password_hash: String.t(),
          failed_attempts: integer(),
          locked_until: DateTime.t() | nil,
          must_change_password: boolean(),
          password_changed_at: DateTime.t(),
          previous_password_hashes: [String.t()],
          user: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "credentials" do
    # The hashed password - never store plain text
    field(:password_hash, :string)

    # Account lockout tracking
    field(:failed_attempts, :integer, default: 0)
    field(:locked_until, :utc_datetime)

    # Password lifecycle management
    field(:must_change_password, :boolean, default: false)
    field(:password_changed_at, :utc_datetime)

    # Password history to prevent reuse
    # Stored as JSON array of previous hashes
    field(:previous_password_hashes, {:array, :string}, default: [])

    # Relationship to user
    belongs_to(:user, User)

    timestamps(type: :utc_datetime)
  end

  # Changesets
  # Handle password hashing and security tracking

  @doc """
  Creates a new credential with a hashed password.

  This is typically called when creating a new user. The password
  is hashed using the configured algorithm before storage.
  """
  def changeset(%Credential{} = credential, attrs) do
    credential
    |> cast(attrs, [:user_id])
    |> validate_required([:user_id])
    |> foreign_key_constraint(:user_id)
    |> put_password_hash(attrs)
  end

  @doc """
  Updates the password with a new hash.

  Used for password changes. Maintains password history and updates
  the password_changed_at timestamp. Clears any lockout status.
  """
  def password_changeset(%Credential{} = credential, password) when is_binary(password) do
    credential
    |> change()
    |> put_password_hash(%{"password" => password})
    |> update_password_history()
    |> put_change(:password_changed_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> put_change(:must_change_password, false)
    |> clear_lockout()
  end

  @doc """
  Records a failed login attempt.

  Increments the failed attempt counter and locks the account if the
  maximum attempts have been exceeded. The lockout duration is configurable.
  """
  def record_failed_attempt(%Credential{} = credential) do
    failed_attempts = credential.failed_attempts + 1
    max_attempts = TidelandLedger.Config.max_failed_attempts()

    changeset = change(credential, failed_attempts: failed_attempts)

    if failed_attempts >= max_attempts do
      lockout_duration = TidelandLedger.Config.lockout_duration_minutes()

      locked_until =
        DateTime.utc_now()
        |> DateTime.add(lockout_duration * 60, :second)
        |> DateTime.truncate(:second)

      put_change(changeset, :locked_until, locked_until)
    else
      changeset
    end
  end

  @doc """
  Clears failed attempts after successful login.

  Resets the attempt counter and removes any lockout. Called automatically
  after successful authentication.
  """
  def clear_failed_attempts(%Credential{} = credential) do
    credential
    |> change()
    |> put_change(:failed_attempts, 0)
    |> put_change(:locked_until, nil)
  end

  @doc """
  Marks that the user must change their password on next login.

  Used for new accounts or after administrative password resets.
  """
  def require_password_change(%Credential{} = credential) do
    change(credential, must_change_password: true)
  end

  # Helper functions
  # These provide password hashing and validation

  defp put_password_hash(changeset, attrs) do
    password = attrs["password"] || attrs[:password]

    if password && password != "" do
      hash = hash_password(password)
      put_change(changeset, :password_hash, hash)
    else
      changeset
    end
  end

  defp hash_password(password) do
    case TidelandLedger.Config.password_algorithm() do
      "argon2" ->
        Argon2.hash_pwd_salt(password)

      "bcrypt" ->
        Bcrypt.hash_pwd_salt(password)

      algorithm ->
        raise "Unsupported password algorithm: #{algorithm}"
    end
  end

  defp update_password_history(changeset) do
    case get_field(changeset, :password_hash) do
      nil ->
        changeset

      current_hash ->
        history = get_field(changeset, :previous_password_hashes) || []
        # Keep last 5 password hashes
        new_history = [current_hash | Enum.take(history, 4)]
        put_change(changeset, :previous_password_hashes, new_history)
    end
  end

  defp clear_lockout(changeset) do
    changeset
    |> put_change(:failed_attempts, 0)
    |> put_change(:locked_until, nil)
  end

  # Validation functions
  # Check password policies and security rules

  @doc """
  Checks if a password matches the stored hash.

  Supports both Argon2 and bcrypt algorithms. Returns false for
  any error to prevent timing attacks.
  """
  def valid_password?(%Credential{password_hash: hash}, password)
      when is_binary(hash) and is_binary(password) do
    case TidelandLedger.Config.password_algorithm() do
      "argon2" ->
        Argon2.verify_pass(password, hash)

      "bcrypt" ->
        Bcrypt.verify_pass(password, hash)

      _ ->
        false
    end
  rescue
    _ -> false
  end

  def valid_password?(_credential, _password), do: false

  @doc """
  Checks if the account is currently locked.

  An account is locked if locked_until is set and is still in the future.
  """
  def locked?(%Credential{locked_until: nil}), do: false

  def locked?(%Credential{locked_until: locked_until}) do
    DateTime.compare(locked_until, DateTime.utc_now()) == :gt
  end

  @doc """
  Checks if a password has been used before.

  Prevents password reuse by checking against the password history.
  """
  def password_used_before?(%Credential{previous_password_hashes: history}, password) do
    Enum.any?(history || [], fn old_hash ->
      case TidelandLedger.Config.password_algorithm() do
        "argon2" -> Argon2.verify_pass(password, old_hash)
        "bcrypt" -> Bcrypt.verify_pass(password, old_hash)
        _ -> false
      end
    end)
  rescue
    _ -> false
  end

  @doc """
  Returns the time until the account unlocks.

  Returns nil if the account is not locked, or the number of seconds
  until the lockout expires.
  """
  def seconds_until_unlock(%Credential{locked_until: nil}), do: nil

  def seconds_until_unlock(%Credential{locked_until: locked_until}) do
    case DateTime.diff(locked_until, DateTime.utc_now()) do
      seconds when seconds > 0 -> seconds
      _ -> nil
    end
  end

  @doc """
  Checks if the password is due for a change based on age.

  Can be used to implement password expiration policies in the future.
  Currently returns false as password expiration is not implemented.
  """
  def password_expired?(%Credential{password_changed_at: nil}), do: false

  def password_expired?(%Credential{password_changed_at: _changed_at}) do
    # Password expiration not currently implemented
    # Could check against a configurable max age here
    false
  end
end
