defmodule TidelandLedger.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:username, :string, null: false)
      add(:email, :string, null: false)
      add(:role, :string, null: false)
      add(:active, :boolean, default: true, null: false)
      add(:last_login_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:users, [:username]))
    create(unique_index(:users, [:email]))
    create(index(:users, [:role]))
    create(index(:users, [:active]))
    create(index(:users, [:last_login_at]))
  end
end
