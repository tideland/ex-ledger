defmodule TidelandLedger.Templates.TemplateLine do
  @moduledoc """
  Represents a single line item within a transaction template.

  Template lines define how money flows between accounts when the template
  is applied. They can use either fixed amounts or percentage-based distribution.

  Lines within a template must balance to zero when the template is applied,
  following the same rules as regular transaction positions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias TidelandLedger.Templates.Template
  alias TidelandLedger.Accounts.Account

  @amount_types [:fixed, :percentage]

  @type amount_type :: :fixed | :percentage
  @type t :: %__MODULE__{
          id: integer() | nil,
          template_id: integer(),
          account_id: integer(),
          description: String.t() | nil,
          amount_type: amount_type(),
          amount_value: Decimal.t(),
          fraction: Decimal.t(),
          tax_relevant: boolean(),
          position: integer(),
          template: Template.t() | Ecto.Association.NotLoaded.t(),
          account: Account.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "template_lines" do
    field :description, :string
    field :amount_type, Ecto.Enum, values: @amount_types, default: :fixed
    field :amount_value, :decimal
    field :fraction, :decimal, default: Decimal.new("1.0")
    field :tax_relevant, :boolean, default: false
    field :position, :integer

    belongs_to :template, Template
    belongs_to :account, Account

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a template line.

  Validates that the amount is appropriate for the selected amount type.
  For percentage-based lines, values must be between 0 and 100.
  """
  def changeset(line, attrs) do
    line
    |> cast(attrs, [
      :template_id,
      :account_id,
      :description,
      :amount_type,
      :amount_value,
      :fraction,
      :tax_relevant,
      :position
    ])
    |> validate_required([:account_id, :amount_type, :amount_value, :position])
    |> validate_length(:description, max: 200)
    |> validate_number(:position, greater_than: 0)
    |> validate_amount_by_type()
    |> foreign_key_constraint(:template_id)
    |> foreign_key_constraint(:account_id)
  end

  @doc """
  Calculates the actual amount for a line when applying the template.

  For fixed amounts, returns the amount value directly.
  For percentage-based amounts, calculates the percentage of the total.
  """
  def calculate_amount(%__MODULE__{amount_type: :fixed} = line, _total) do
    line.amount_value
  end

  def calculate_amount(%__MODULE__{amount_type: :percentage} = line, total) when not is_nil(total) do
    Decimal.mult(total, line.amount_value)
    |> Decimal.div(Decimal.new("100"))
    |> Decimal.round(2)
  end

  def calculate_amount(%__MODULE__{amount_type: :percentage}, nil) do
    raise ArgumentError, "Total amount is required for percentage-based template lines"
  end

  @doc """
  Calculates the actual amount for a line based on the fraction when distributing the total.
  """
  def calculate_fraction_amount(%__MODULE__{} = line, total) when not is_nil(total) do
    Decimal.mult(total, line.fraction)
    |> Decimal.round(2)
  end

  def calculate_fraction_amount(_line, nil) do
    raise ArgumentError, "Total amount is required for fraction-based template lines"
  end

  # Private helpers

  defp validate_amount_by_type(changeset) do
    amount_type = get_field(changeset, :amount_type)
    amount_value = get_field(changeset, :amount_value)

    case {amount_type, amount_value} do
      {:percentage, value} when not is_nil(value) ->
        validate_number(changeset, :amount_value, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)

      _ ->
        changeset
    end
  end
end
