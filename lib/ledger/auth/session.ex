defmodule TidelandLedger.Auth.Session do
  @moduledoc """
  Session schema for user session management.

  This module handles the creation and validation of user sessions. Sessions
  are stored in the database with secure random tokens and configurable expiration.
  The system supports sliding expiration where session lifetime extends with activity.

  Sessions track additional metadata like IP address and user agent for security
  auditing. Old expired sessions are cleaned up periodically by a background job.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias TidelandLedger.Auth.{User, Session}

  @type t :: %__MODULE__{
          token: String.t(),
          user_id: integer(),
          expires_at: DateTime.t(),
          ip_address: String.t() | nil,
          user_agent: String.t() | nil,
          last_activity_at: DateTime.t(),
          user: User.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil
        }

  # Session token length in bytes (will be base64 encoded)
  @token_bytes 32

  @primary_key {:token, :string, autogenerate: false}
  schema "sessions" do
    # Session metadata
    field(:expires_at, :utc_datetime)
    field(:ip_address, :string)
    field(:user_agent, :string)
    field(:last_activity_at, :utc_datetime)

    # User relationship
    belongs_to(:user, User, type: :binary_id)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  # Changesets
  # Handle session creation and updates

  @doc """
  Creates a new session for a user.

  Generates a secure random token and sets the expiration based on
  the configured session timeout. Stores request metadata for auditing.
  """
  def create_changeset(user_id, attrs \\ %{}) do
    token = generate_token()
    timeout_minutes = TidelandLedger.Config.session_timeout_minutes()
    expires_at = calculate_expiration(timeout_minutes)

    %Session{token: token}
    |> cast(attrs, [:ip_address, :user_agent])
    |> put_change(:user_id, user_id)
    |> put_change(:expires_at, expires_at)
    |> put_change(:last_activity_at, DateTime.utc_now() |> DateTime.truncate(:second))
    |> validate_required([:user_id, :expires_at, :last_activity_at])
    # IPv6 max length
    |> validate_length(:ip_address, max: 45)
    |> validate_length(:user_agent, max: 500)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Updates session activity timestamp and optionally extends expiration.

  Called on each authenticated request to track activity and implement
  sliding expiration if enabled.
  """
  def touch_changeset(%Session{} = session) do
    changeset =
      session
      |> change()
      |> put_change(:last_activity_at, DateTime.utc_now() |> DateTime.truncate(:second))

    if TidelandLedger.Config.session_sliding_expiration?() do
      timeout_minutes = TidelandLedger.Config.session_timeout_minutes()
      new_expiration = calculate_expiration(timeout_minutes)
      put_change(changeset, :expires_at, new_expiration)
    else
      changeset
    end
  end

  # Query functions
  # Common queries for session management

  @doc """
  Returns a query for valid (non-expired) sessions.
  """
  def valid_sessions_query do
    now = DateTime.utc_now()
    from(s in Session, where: s.expires_at > ^now)
  end

  @doc """
  Returns a query for expired sessions that can be cleaned up.
  """
  def expired_sessions_query do
    now = DateTime.utc_now()
    from(s in Session, where: s.expires_at <= ^now)
  end

  @doc """
  Returns a query for sessions belonging to a specific user.
  """
  def by_user_query(user_id) do
    from(s in Session,
      where: s.user_id == ^user_id,
      order_by: [desc: s.last_activity_at]
    )
  end

  @doc """
  Returns a query for finding a valid session by token.
  """
  def get_valid_session_query(token) do
    now = DateTime.utc_now()

    from(s in Session,
      where: s.token == ^token and s.expires_at > ^now,
      preload: [:user]
    )
  end

  # Helper functions
  # Session token generation and validation

  @doc """
  Generates a cryptographically secure session token.

  Uses Erlang's crypto module to generate random bytes, then encodes
  them as URL-safe base64 for use in cookies and URLs.
  """
  def generate_token do
    @token_bytes
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Checks if a session is currently valid.

  A session is valid if it exists, hasn't expired, and belongs to an active user.
  """
  def valid?(%Session{expires_at: expires_at, user: %User{active: active}}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :gt and active
  end

  def valid?(%Session{expires_at: expires_at}) do
    DateTime.compare(expires_at, DateTime.utc_now()) == :gt
  end

  @doc """
  Returns the remaining lifetime of a session in seconds.

  Returns 0 if the session has expired.
  """
  def remaining_seconds(%Session{expires_at: expires_at}) do
    case DateTime.diff(expires_at, DateTime.utc_now()) do
      seconds when seconds > 0 -> seconds
      _ -> 0
    end
  end

  @doc """
  Checks if a session needs to be refreshed.

  A session should be refreshed if more than half its lifetime has passed
  and sliding expiration is enabled.
  """
  def needs_refresh?(%Session{} = session) do
    if TidelandLedger.Config.session_sliding_expiration?() do
      total_lifetime = TidelandLedger.Config.session_timeout_minutes() * 60
      remaining = remaining_seconds(session)
      remaining < total_lifetime / 2
    else
      false
    end
  end

  @doc """
  Returns session metadata for logging and debugging.
  """
  def metadata(%Session{} = session) do
    %{
      session_id: String.slice(session.token, 0, 8) <> "...",
      user_id: session.user_id,
      ip_address: session.ip_address,
      expires_at: session.expires_at,
      last_activity: session.last_activity_at
    }
  end

  # Private functions

  defp calculate_expiration(timeout_minutes) do
    DateTime.utc_now()
    |> DateTime.add(timeout_minutes * 60, :second)
    |> DateTime.truncate(:second)
  end

  @doc """
  Validates a session token format.

  Ensures the token has the expected length and character set.
  Used to quickly reject invalid tokens without database lookup.
  """
  def valid_token_format?(token) when is_binary(token) do
    # Base64 URL-encoded 32 bytes = 43 characters (no padding)
    String.length(token) == 43 and String.match?(token, ~r/^[A-Za-z0-9_-]+$/)
  end

  def valid_token_format?(_), do: false
end
