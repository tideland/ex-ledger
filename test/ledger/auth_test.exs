defmodule TidelandLedger.AuthTest do
  use TidelandLedger.DataCase, async: true

  import TidelandLedger.Factory

  alias TidelandLedger.Auth
  alias TidelandLedger.Auth.{User, Credential, Session}

  describe "create_user/1" do
    test "creates user with valid attributes" do
      attrs = %{
        username: "testuser",
        email: "test@example.com",
        role: :bookkeeper,
        password: "SecurePassword123",
        password_confirmation: "SecurePassword123"
      }

      assert {:ok, user} = Auth.create_user(attrs)
      assert user.username == "testuser"
      assert user.email == "test@example.com"
      assert user.role == :bookkeeper
      assert user.active == true

      # Verify credential was created
      user = Repo.preload(user, :credential)
      assert user.credential != nil
      assert user.credential.password_hash != nil
    end

    test "validates required fields" do
      attrs = %{username: "testuser"}

      assert {:error, changeset} = Auth.create_user(attrs)
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates password confirmation" do
      attrs = %{
        username: "testuser",
        email: "test@example.com",
        role: :bookkeeper,
        password: "SecurePassword123",
        password_confirmation: "DifferentPassword"
      }

      assert {:error, changeset} = Auth.create_user(attrs)
      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end

    test "validates unique username" do
      attrs = %{
        username: "testuser",
        email: "test1@example.com",
        role: :bookkeeper,
        password: "SecurePassword123",
        password_confirmation: "SecurePassword123"
      }

      assert {:ok, _user} = Auth.create_user(attrs)

      # Try to create another user with same username
      attrs2 = %{attrs | email: "test2@example.com"}
      assert {:error, changeset} = Auth.create_user(attrs2)
      assert %{username: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "authenticate_user/3" do
    setup do
      {:ok, user} =
        Auth.create_user(%{
          username: "testuser",
          email: "test@example.com",
          role: :bookkeeper,
          password: "SecurePassword123",
          password_confirmation: "SecurePassword123"
        })

      %{user: user}
    end

    test "authenticates with correct credentials", %{user: user} do
      session_attrs = %{ip_address: "127.0.0.1", user_agent: "Test Agent"}

      assert {:ok, session} = Auth.authenticate_user("testuser", "SecurePassword123", session_attrs)
      assert session.user_id == user.id
      assert session.ip_address == "127.0.0.1"
      assert session.user_agent == "Test Agent"
    end

    test "rejects incorrect password" do
      result = Auth.authenticate_user("testuser", "WrongPassword", %{})
      assert result == {:error, :invalid_credentials}
    end

    test "rejects non-existent user" do
      result = Auth.authenticate_user("nonexistent", "password", %{})
      assert result == {:error, :invalid_credentials}
    end

    test "updates last login timestamp", %{user: user} do
      assert user.last_login_at == nil

      {:ok, _session} = Auth.authenticate_user("testuser", "SecurePassword123", %{})

      updated_user = Auth.get_user(user.id)
      assert updated_user.last_login_at != nil
    end
  end

  describe "change_user_password/2" do
    setup do
      {:ok, user} =
        Auth.create_user(%{
          username: "testuser",
          email: "test@example.com",
          role: :bookkeeper,
          password: "OldPassword123",
          password_confirmation: "OldPassword123"
        })

      %{user: user}
    end

    test "changes password with valid input", %{user: user} do
      attrs = %{
        password: "NewPassword123",
        password_confirmation: "NewPassword123"
      }

      assert {:ok, _updated_user} = Auth.change_user_password(user, attrs)

      # Verify old password no longer works
      result = Auth.authenticate_user("testuser", "OldPassword123", %{})
      assert result == {:error, :invalid_credentials}

      # Verify new password works
      {:ok, _session} = Auth.authenticate_user("testuser", "NewPassword123", %{})
    end

    test "validates password confirmation", %{user: user} do
      attrs = %{
        password: "NewPassword123",
        password_confirmation: "DifferentPassword"
      }

      assert {:error, changeset} = Auth.change_user_password(user, attrs)
      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end
  end

  describe "can?/2" do
    test "admin can do everything" do
      user = %User{role: :admin}

      assert Auth.can?(user, :manage_users)
      assert Auth.can?(user, :create_entry)
      assert Auth.can?(user, :view_reports)
    end

    test "bookkeeper has limited permissions" do
      user = %User{role: :bookkeeper}

      refute Auth.can?(user, :manage_users)
      assert Auth.can?(user, :create_entry)
      assert Auth.can?(user, :view_reports)
    end

    test "viewer has read-only access" do
      user = %User{role: :viewer}

      refute Auth.can?(user, :manage_users)
      refute Auth.can?(user, :create_entry)
      assert Auth.can?(user, :view_reports)
    end

    test "nil user cannot do anything" do
      refute Auth.can?(nil, :view_reports)
    end
  end

  describe "session management" do
    setup do
      {:ok, user} =
        Auth.create_user(%{
          username: "testuser",
          email: "test@example.com",
          role: :bookkeeper,
          password: "SecurePassword123",
          password_confirmation: "SecurePassword123"
        })

      %{user: user}
    end

    test "creates and validates session", %{user: user} do
      {:ok, session} = Auth.create_session(user, %{ip_address: "127.0.0.1"})

      assert {:ok, validated_session} = Auth.validate_session_token(session.token)
      assert validated_session.user.id == user.id
    end

    test "rejects invalid session token" do
      result = Auth.validate_session_token("invalid_token")
      assert result == {:error, :invalid_session}
    end

    test "invalidates session" do
      {:ok, session} = Auth.create_session(%User{id: 1}, %{})

      assert {:ok, _} = Auth.invalidate_session(session.token)

      result = Auth.validate_session_token(session.token)
      assert result == {:error, :invalid_session}
    end
  end

  describe "cleanup_expired_sessions/0" do
    test "removes expired sessions" do
      # Create an expired session by manipulating the expiration
      user = insert(:user)
      {:ok, session} = Auth.create_session(user, %{})

      # Manually expire the session
      expired_time = DateTime.add(DateTime.utc_now(), -1, :hour)
      Repo.update!(Ecto.Changeset.change(session, expires_at: expired_time))

      assert {:ok, count} = Auth.cleanup_expired_sessions()
      assert count >= 1

      # Verify session is gone
      result = Auth.validate_session_token(session.token)
      assert result == {:error, :invalid_session}
    end
  end
end
