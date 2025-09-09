defmodule TidelandLedger.Repo.Migrations.CreatePositions do
  use Ecto.Migration

  def change do
    create table(:positions, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:entry_id, references(:entries, type: :binary_id, on_delete: :delete_all), null: false)
      add(:account_id, references(:accounts, type: :binary_id), null: false)
      add(:position, :integer, null: false)
      add(:amount, :map, null: false)
      add(:description, :string)
      add(:tax_relevant, :boolean, default: false, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:positions, [:entry_id]))
    create(index(:positions, [:account_id]))
    create(index(:positions, [:tax_relevant]))
    create(unique_index(:positions, [:entry_id, :position]))
  end
end
