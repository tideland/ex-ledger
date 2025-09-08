defmodule TidelandLedger.Repo.Migrations.CreateEntries do
  use Ecto.Migration

  def change do
    create table(:entries, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:date, :date, null: false)
      add(:description, :string, null: false)
      add(:reference, :string)
      add(:status, :string, null: false, default: "draft")
      add(:created_by_id, references(:users, type: :binary_id), null: false)
      add(:posted_by_id, references(:users, type: :binary_id))
      add(:posted_at, :utc_datetime)
      add(:voided_by_id, references(:users, type: :binary_id))
      add(:voided_at, :utc_datetime)
      add(:void_reason, :string)

      timestamps(type: :utc_datetime)
    end

    create(index(:entries, [:date]))
    create(index(:entries, [:status]))
    create(index(:entries, [:reference]))
    create(index(:entries, [:created_by_id]))
    create(index(:entries, [:posted_by_id]))
    create(index(:entries, [:voided_by_id]))
    create(index(:entries, [:posted_at]))
    create(index(:entries, [:voided_at]))
  end
end
