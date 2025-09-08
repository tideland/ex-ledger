defmodule TidelandLedger.Repo.Migrations.CreateCredentials do
  use Ecto.Migration

  def change do
    create table(:credentials, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false)
      add(:password_hash, :string, null: false)
      add(:password_changed_at, :utc_datetime)
      add(:must_change_password, :boolean, default: false, null: false)
      add(:previous_password_hashes, {:array, :string}, default: [])
      add(:failed_attempts, :integer, default: 0, null: false)
      add(:locked_until, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:credentials, [:user_id]))
    create(index(:credentials, [:locked_until]))
    create(index(:credentials, [:failed_attempts]))
  end
end
