defmodule TidelandLedger.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:path, :string, null: false)
      add(:name, :string, null: false)
      add(:description, :string)
      add(:parent_path, :string)
      add(:depth, :integer, null: false)
      add(:active, :boolean, default: true, null: false)
      add(:created_by_id, references(:users, type: :binary_id), null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:accounts, [:path]))
    create(index(:accounts, [:parent_path]))
    create(index(:accounts, [:depth]))
    create(index(:accounts, [:active]))
    create(index(:accounts, [:name]))
    create(index(:accounts, [:created_by_id]))
  end
end
