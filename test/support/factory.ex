defmodule TidelandLedger.Factory do
  @moduledoc """
  Factory for creating test data.

  This module provides functions to create valid test data for all schemas
  in the application. It uses ExMachina for consistent test data generation.
  """

  use ExMachina.Ecto, repo: TidelandLedger.Repo

  alias TidelandLedger.Auth.{User, Credential, Session}
  alias TidelandLedger.Accounts.Account
  alias TidelandLedger.Transactions.{Entry, Position}
  alias TidelandLedger.Amount

  # User factories

  def user_factory do
    %User{
      username: sequence(:username, &"user#{&1}"),
      email: sequence(:email, &"user#{&1}@example.com"),
      role: :bookkeeper,
      active: true,
      last_login_at: nil
    }
  end

  def admin_user_factory do
    build(:user, role: :admin)
  end

  def viewer_user_factory do
    build(:user, role: :viewer)
  end

  def inactive_user_factory do
    build(:user, active: false)
  end

  # Credential factories

  def credential_factory do
    %Credential{
      user: build(:user),
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      failed_attempts: 0,
      locked_until: nil,
      must_change_password: false,
      password_changed_at: DateTime.utc_now() |> DateTime.truncate(:second),
      previous_password_hashes: []
    }
  end

  def locked_credential_factory do
    build(:credential,
      failed_attempts: 5,
      locked_until: DateTime.add(DateTime.utc_now(), 15 * 60, :second)
    )
  end

  # Session factories

  def session_factory do
    user = insert(:user)
    timeout_minutes = TidelandLedger.Config.session_timeout_minutes()

    %Session{
      token: Session.generate_token(),
      user: user,
      expires_at: DateTime.add(DateTime.utc_now(), timeout_minutes * 60, :second),
      ip_address: "127.0.0.1",
      user_agent: "Test User Agent",
      last_activity_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }
  end

  def expired_session_factory do
    build(:session,
      expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
    )
  end

  # Account factories

  def account_factory do
    user = insert(:user)
    path = sequence(:account_path, ["Ausgaben", "Einnahmen", "Vermögen", "Schulden"], & &1)

    %Account{
      path: path,
      # For root accounts, name equals path
      name: path,
      description: "Test account for #{path}",
      parent_path: nil,
      depth: 1,
      active: true,
      created_by: user
    }
  end

  def child_account_factory do
    parent = insert(:account)
    user = insert(:user)
    name = sequence(:child_name, &"Child#{&1}")

    %Account{
      path: "#{parent.path} : #{name}",
      name: name,
      description: "Test child account",
      parent_path: parent.path,
      depth: parent.depth + 1,
      active: true,
      created_by: user
    }
  end

  def inactive_account_factory do
    build(:account, active: false)
  end

  # Entry factories

  def entry_factory do
    user = insert(:user)

    %Entry{
      date: Date.utc_today(),
      description: sequence(:description, &"Test entry #{&1}"),
      reference: sequence(:reference, &"REF#{&1}"),
      status: :draft,
      created_by: user,
      positions: []
    }
  end

  def posted_entry_factory do
    user = insert(:user)

    build(:entry,
      status: :posted,
      posted_by: user,
      posted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
  end

  def void_entry_factory do
    user = insert(:user)

    build(:posted_entry,
      status: :void,
      voided_by: user,
      voided_at: DateTime.utc_now() |> DateTime.truncate(:second),
      void_reason: "Test void reason"
    )
  end

  # Position factories

  def position_factory do
    entry = insert(:entry)
    account = insert(:account)

    %Position{
      entry: entry,
      account: account,
      position: 1,
      amount: Amount.new(100),
      description: "Test position",
      tax_relevant: false
    }
  end

  def balanced_entry_with_positions_factory do
    user = insert(:user)
    expense_account = insert(:account, path: "Ausgaben : Test")
    cash_account = insert(:account, path: "Vermögen : Kasse")

    entry = insert(:entry, created_by: user)

    # Create balanced positions
    insert(:position,
      entry: entry,
      account: expense_account,
      position: 1,
      amount: Amount.new(100),
      description: "Test expense"
    )

    insert(:position,
      entry: entry,
      account: cash_account,
      position: 2,
      amount: Amount.new(-100),
      description: "Cash payment"
    )

    # Reload entry with positions
    TidelandLedger.Repo.preload(entry, :positions, force: true)
  end

  # Helper functions for creating related data

  def user_with_credential_factory do
    user = build(:user)
    credential = build(:credential, user: user)

    %{user | credential: credential}
  end

  def complete_user_factory do
    password = "SecurePassword123"

    user = insert(:user)

    insert(:credential,
      user: user,
      password_hash: Bcrypt.hash_pwd_salt(password)
    )

    # Return user preloaded with credential and set virtual password field
    user
    |> TidelandLedger.Repo.preload(:credential)
    |> Map.put(:password, password)
  end

  def account_hierarchy_factory do
    user = insert(:user)

    # Create root account
    root =
      insert(:account,
        path: "Ausgaben",
        name: "Ausgaben",
        parent_path: nil,
        depth: 1,
        created_by: user
      )

    # Create child account
    child =
      insert(:account,
        path: "Ausgaben : Büro",
        name: "Büro",
        parent_path: "Ausgaben",
        depth: 2,
        created_by: user
      )

    # Create grandchild account
    grandchild =
      insert(:account,
        path: "Ausgaben : Büro : Material",
        name: "Material",
        parent_path: "Ausgaben : Büro",
        depth: 3,
        created_by: user
      )

    %{root: root, child: child, grandchild: grandchild}
  end

  # Amount helper
  def amount(value, currency \\ "EUR") do
    Amount.new(value, currency)
  end

  # Random test data generators

  def random_amount(min \\ 1, max \\ 1000) do
    value = Enum.random(min..max) + :rand.uniform()
    Amount.new(value)
  end

  def random_date(days_ago \\ 30) do
    Date.add(Date.utc_today(), -Enum.random(0..days_ago))
  end

  def random_account_path do
    roots = ["Ausgaben", "Einnahmen", "Vermögen", "Schulden"]
    segments = ["Büro", "Material", "Personal", "Technik", "Miete", "Versicherung"]

    root = Enum.random(roots)
    depth = Enum.random(1..3)

    case depth do
      1 -> root
      2 -> "#{root} : #{Enum.random(segments)}"
      3 -> "#{root} : #{Enum.random(segments)} : #{Enum.random(segments)}"
    end
  end
end
