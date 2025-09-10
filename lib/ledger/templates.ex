defmodule TidelandLedger.Templates do
  @moduledoc """
  The Templates context manages the transaction templates system.

  This module provides the public API for creating and applying templates
  that represent reusable transaction patterns. Templates are immutable
  and versioned - once created, they cannot be modified. New versions must
  be created to represent changes.

  Templates support both fixed amounts and percentage-based distributions,
  allowing for flexible reuse across different transaction scenarios.
  """

  import Ecto.Query

  alias TidelandLedger.Repo
  alias TidelandLedger.Templates.{Template, TemplateLine}
  alias TidelandLedger.Amount

  # Template Querying
  # Functions for retrieving and listing templates

  @doc """
  Returns a list of all templates.

  Templates are grouped by name, with only the latest version of each template
  included by default.

  ## Options

    * `:include_all_versions` - When true, includes all versions of templates
    * `:preload` - Associations to preload (defaults to [:lines, :created_by])
    * `:active_only` - When true, only includes active templates

  ## Examples

      iex> list_templates()
      [%Template{}, ...]

      iex> list_templates(include_all_versions: true)
      [%Template{}, ...]
  """
  def list_templates(opts \\ []) do
    include_all_versions = Keyword.get(opts, :include_all_versions, false)
    preloads = Keyword.get(opts, :preload, [:lines, :created_by])
    active_only = Keyword.get(opts, :active_only, false)

    query = from(t in Template)

    query =
      if active_only do
        where(query, [t], t.active == true)
      else
        query
      end

    # If we only want the latest version of each template, we need to use a subquery
    query =
      if include_all_versions do
        query
      else
        latest_versions =
          from(t in Template,
            group_by: t.name,
            select: %{name: t.name, max_version: max(t.version)}
          )

        from(t in query,
          join: lv in subquery(latest_versions),
          on: t.name == lv.name and t.version == lv.max_version
        )
      end

    query
    |> order_by([t], asc: t.name, desc: t.version)
    |> preload(^preloads)
    |> Repo.all()
  end

  @doc """
  Gets a single template by ID.

  Raises `Ecto.NoResultsError` if the Template does not exist.

  ## Examples

      iex> get_template!(123)
      %Template{}

      iex> get_template!(456)
      ** (Ecto.NoResultsError)
  """
  def get_template!(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [:lines, :created_by])

    Template
    |> preload(^preloads)
    |> Repo.get!(id)
  end

  @doc """
  Gets a specific version of a template by name and version.

  Returns nil if the template does not exist.

  ## Examples

      iex> get_template_version("Monthly Rent", 2)
      %Template{}

      iex> get_template_version("Non-existent", 1)
      nil
  """
  def get_template_version(name, version, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [:lines, :created_by])

    Template
    |> where([t], t.name == ^name and t.version == ^version)
    |> preload(^preloads)
    |> Repo.one()
  end

  @doc """
  Gets the latest version of a template by name.

  Returns nil if the template does not exist.

  ## Examples

      iex> get_latest_template("Monthly Rent")
      %Template{}

      iex> get_latest_template("Non-existent")
      nil
  """
  def get_latest_template(name, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [:lines, :created_by])

    Template.latest_version_query(name)
    |> preload(^preloads)
    |> Repo.one()
  end

  @doc """
  Lists all versions of a template by name.

  Returns an empty list if the template does not exist.

  ## Examples

      iex> list_template_versions("Monthly Rent")
      [%Template{version: 3}, %Template{version: 2}, %Template{version: 1}]

      iex> list_template_versions("Non-existent")
      []
  """
  def list_template_versions(name, opts \\ []) do
    preloads = Keyword.get(opts, :preload, [:lines, :created_by])

    Template.versions_query(name)
    |> preload(^preloads)
    |> Repo.all()
  end

  # Template Management
  # Functions for creating and managing templates

  @doc """
  Creates a new template.

  ## Examples

      iex> create_template(%{
      ...>   name: "Monthly Rent",
      ...>   description: "Regular monthly rent payment",
      ...>   default_total: Decimal.new("1500.00"),
      ...>   lines: [
      ...>     %{account_id: 1, amount_type: :fixed, amount_value: Decimal.new("1500.00"), position: 1},
      ...>     %{account_id: 2, amount_type: :fixed, amount_value: Decimal.new("-1500.00"), position: 2}
      ...>   ],
      ...>   created_by_id: 1
      ...> })
      {:ok, %Template{}}

      iex> create_template(%{name: nil})
      {:error, %Ecto.Changeset{}}
  """
  def create_template(attrs \\ %{}) do
    # Check if we need to increment the version
    attrs = maybe_increment_version(attrs)

    %Template{}
    |> Template.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a new version of an existing template.

  ## Examples

      iex> create_new_version(template, %{
      ...>   description: "Updated rent amount",
      ...>   default_total: Decimal.new("1600.00"),
      ...>   lines: [
      ...>     %{account_id: 1, amount_type: :fixed, amount_value: Decimal.new("1600.00"), position: 1},
      ...>     %{account_id: 2, amount_type: :fixed, amount_value: Decimal.new("-1600.00"), position: 2}
      ...>   ]
      ...> })
      {:ok, %Template{}}
  """
  def create_new_version(%Template{} = template, attrs) do
    # Force the next version number and keep the same name
    attrs =
      Map.merge(attrs, %{
        name: template.name,
        version: template.version + 1
      })

    # Create the new version
    %Template{}
    |> Template.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Activates or deactivates a template.

  Templates cannot be deleted, but they can be deactivated to hide them
  from the UI and prevent them from being used.

  ## Examples

      iex> set_template_active(template, true)
      {:ok, %Template{}}
  """
  def set_template_active(%Template{} = template, active) when is_boolean(active) do
    template
    |> Ecto.Changeset.change(active: active)
    |> Repo.update()
  end

  # Template Application
  # Functions for applying templates to create entries

  @doc """
  Applies a template to create entry attributes.

  Returns a map of attributes that can be used to create a new entry.
  For percentage-based templates, a total_amount must be provided.

  ## Examples

      iex> apply_template(template, Decimal.new("1000.00"), %{
      ...>   date: ~D[2023-01-15],
      ...>   description: "January Rent Payment",
      ...>   created_by_id: 1
      ...> })
      {:ok, %{
        date: ~D[2023-01-15],
        description: "January Rent Payment",
        created_by_id: 1,
        positions: [
          %{account_id: 1, amount: %Amount{cents: 100000}, position: 1},
          %{account_id: 2, amount: %Amount{cents: -100000}, position: 2}
        ]
      }}
  """
  def apply_template(%Template{} = template, total_amount \\ nil, entry_attrs \\ %{}) do
    # Use default_total if no total_amount is provided
    total =
      cond do
        total_amount ->
          total_amount

        template.default_total ->
          template.default_total

        true ->
          nil
      end

    # Check if we have percentage lines but no total
    has_percentage = Enum.any?(template.lines, &(&1.amount_type == :percentage))

    if has_percentage && is_nil(total) do
      {:error, :total_amount_required}
    else
      # Calculate positions based on template lines
      positions =
        template.lines
        |> Enum.map(fn line ->
          amount =
            case line.amount_type do
              :fixed -> line.amount_value
              :percentage -> TemplateLine.calculate_amount(line, total)
            end

          %{
            account_id: line.account_id,
            description: line.description,
            amount: to_amount(amount),
            tax_relevant: line.tax_relevant,
            position: line.position
          }
        end)

      # Check if positions balance
      positions_result =
        if positions_balance?(positions) do
          positions
        else
          # Apply balancing correction
          balance_positions(positions)
        end

      # Merge entry attrs with positions
      entry = Map.merge(entry_attrs, %{positions: positions_result})
      {:ok, entry}
    end
  end

  @doc """
  Applies a template using fractions instead of fixed or percentage amounts.

  This is useful for distributing a total amount across multiple accounts
  according to predefined fractions.

  ## Examples

      iex> apply_template_with_fractions(template, Decimal.new("1200.00"), %{
      ...>   date: ~D[2023-01-15],
      ...>   description: "Office expenses",
      ...>   created_by_id: 1
      ...> })
      {:ok, %{
        date: ~D[2023-01-15],
        description: "Office expenses",
        created_by_id: 1,
        positions: [
          %{account_id: 1, amount: %Amount{cents: 80000}, position: 1},  # 2/3 of total
          %{account_id: 2, amount: %Amount{cents: 40000}, position: 2},  # 1/3 of total
          %{account_id: 3, amount: %Amount{cents: -120000}, position: 3} # -1 (balancing)
        ]
      }}
  """
  def apply_template_with_fractions(%Template{} = template, total_amount, entry_attrs \\ %{}) do
    if is_nil(total_amount) do
      {:error, :total_amount_required}
    else
      # Calculate positions based on fractions
      positions =
        template.lines
        |> Enum.map(fn line ->
          amount = TemplateLine.calculate_fraction_amount(line, total_amount)

          %{
            account_id: line.account_id,
            description: line.description,
            amount: to_amount(amount),
            tax_relevant: line.tax_relevant,
            position: line.position
          }
        end)

      # Check if positions balance
      positions_result =
        if positions_balance?(positions) do
          positions
        else
          # Apply balancing correction
          balance_positions(positions)
        end

      # Merge entry attrs with positions
      entry = Map.merge(entry_attrs, %{positions: positions_result})
      {:ok, entry}
    end
  end

  # Private helpers

  defp maybe_increment_version(%{name: name} = attrs) when is_binary(name) do
    # Check if a template with this name already exists
    case get_latest_template(name) do
      nil ->
        # No existing template, use version 1
        Map.put_new(attrs, :version, 1)

      %Template{version: latest_version} ->
        # Template exists, increment version
        Map.put(attrs, :version, latest_version + 1)
    end
  end

  defp maybe_increment_version(attrs), do: attrs

  defp to_amount(decimal) do
    # Convert from Decimal to Amount
    # Pass Decimal value directly to Amount.new without converting to float
    # The Amount.new/1 function can handle Decimal values correctly
    Amount.new(decimal)
  end

  defp positions_balance?(positions) do
    # Check if positions sum to zero
    sum =
      positions
      |> Enum.map(& &1.amount)
      |> Amount.sum()

    Amount.zero?(sum)
  end

  defp balance_positions(positions) do
    # Find the sum of all positions
    sum =
      positions
      |> Enum.map(& &1.amount)
      |> Amount.sum()

    # If already balanced, return as is
    if Amount.zero?(sum) do
      positions
    else
      # Find the last position with the largest absolute value to adjust
      {max_position_index, _} =
        positions
        |> Enum.with_index()
        |> Enum.max_by(fn {pos, _} -> Amount.abs(pos.amount) end)

      # Adjust that position to make the sum zero
      List.update_at(positions, max_position_index, fn position ->
        adjusted_amount = Amount.subtract(position.amount, sum)
        %{position | amount: adjusted_amount}
      end)
    end
  end
end
