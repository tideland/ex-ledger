defmodule TidelandLedger.Templates.Template do
  @moduledoc """
  Represents a transaction template in the ledger system.

  Templates provide reusable transaction patterns that can be applied to create
  new entries. They support both fixed amounts and percentage-based distributions.

  Templates are immutable and versioned - once created, they cannot be modified.
  Instead, new versions must be created to represent changes. This ensures that
  references to templates remain stable over time.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias TidelandLedger.Templates.TemplateLine
  alias TidelandLedger.Auth.User

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t(),
          version: integer(),
          description: String.t() | nil,
          default_total: Decimal.t() | nil,
          active: boolean(),
          created_by_id: integer(),
          created_by: User.t() | Ecto.Association.NotLoaded.t(),
          lines: [TemplateLine.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "templates" do
    field :name, :string
    field :version, :integer, default: 1
    field :description, :string
    field :default_total, :decimal
    field :active, :boolean, default: true
    field :created_by_id, :integer

    belongs_to :created_by, User, foreign_key: :created_by_id, define_field: false
    has_many :lines, TemplateLine, on_replace: :mark_as_invalid

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a new template.

  Validates required fields and ensures the template follows business rules.
  Template lines are validated through nested changesets.
  """
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:name, :version, :description, :default_total, :active, :created_by_id])
    |> validate_required([:name, :created_by_id])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_number(:version, greater_than: 0)
    |> cast_assoc(:lines, required: true, with: &TemplateLine.changeset/2)
    |> validate_lines_balance()
    |> unique_constraint([:name, :version], name: :templates_name_version_index)
  end

  @doc """
  Creates a changeset for a new version of an existing template.

  This validates that the version is incremented correctly.
  """
  def new_version_changeset(template, attrs) do
    template
    |> changeset(attrs)
    |> validate_change(:version, fn :version, version ->
      if version <= template.version do
        [version: "must be greater than the current version #{template.version}"]
      else
        []
      end
    end)
  end

  @doc """
  Returns a query to find the latest version of a template by name.
  """
  def latest_version_query(name) do
    from t in __MODULE__,
      where: t.name == ^name,
      order_by: [desc: t.version],
      limit: 1,
      preload: [lines: :account]
  end

  @doc """
  Returns a query for all versions of a template by name.
  """
  def versions_query(name) do
    from t in __MODULE__,
      where: t.name == ^name,
      order_by: [desc: t.version],
      preload: [lines: :account]
  end

  @doc """
  Returns a query for active templates.
  """
  def active_query do
    from t in __MODULE__,
      where: t.active == true,
      order_by: [asc: t.name, desc: t.version],
      preload: [lines: :account]
  end

  @doc """
  Checks if two templates have the same name.
  """
  def same_template?(template1, template2) do
    template1.name == template2.name
  end

  # Private helpers

  defp validate_lines_balance(changeset) do
    lines = get_field(changeset, :lines, [])

    # Check if we have both fixed and percentage lines
    has_fixed = Enum.any?(lines, &(&1.amount_type == :fixed))
    has_percentage = Enum.any?(lines, &(&1.amount_type == :percentage))

    if has_fixed && has_percentage do
      add_error(changeset, :lines, "Cannot mix fixed and percentage-based lines in the same template")
    else
      changeset
    end
  end
end
