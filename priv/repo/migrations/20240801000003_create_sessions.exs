defmodule TidelandLedger.Repo.Migrations.CreateSessions do
  use Ecto.Migration

  def change do
    create table(:sessions, primary_key: false) do
      add(:token, :string, primary_key: true, size: 64)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:ip_address, :string)
      add(:user_agent, :string)
      add(:expires_at, :utc_datetime, null: false)
      add(:last_activity_at, :utc_datetime, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:sessions, [:user_id]))
    create(index(:sessions, [:expires_at]))
    create(index(:sessions, [:last_activity_at]))
  end
end
