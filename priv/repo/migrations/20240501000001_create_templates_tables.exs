defmodule TidelandLedger.Repo.Migrations.CreateTemplatesTables do
  use Ecto.Migration

  def change do
    # Templates table
    create table(:templates) do
      add :name, :string, null: false, size: 100
      add :version, :integer, null: false, default: 1
      add :description, :text
      add :default_total, :decimal, precision: 15, scale: 2
      add :active, :boolean, null: false, default: true
      add :created_by_id, references(:users, on_delete: :restrict), null: false

      timestamps()
    end

    # Create indexes for templates
    create index(:templates, [:name])
    create index(:templates, [:active])
    create unique_index(:templates, [:name, :version], name: :templates_name_version_index)

    # Template lines table
    create table(:template_lines) do
      add :template_id, references(:templates, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :restrict), null: false
      add :description, :string, size: 200
      add :amount_type, :string, null: false, default: "fixed"
      add :amount_value, :decimal, precision: 15, scale: 2, null: false
      add :fraction, :decimal, precision: 15, scale: 8, default: 1.0
      add :tax_relevant, :boolean, null: false, default: false
      add :position, :integer, null: false

      timestamps()
    end

    # Create indexes for template lines
    create index(:template_lines, [:template_id])
    create index(:template_lines, [:account_id])
    create index(:template_lines, [:tax_relevant])
  end
end
