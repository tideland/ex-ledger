defmodule TidelandLedger.TemplatesTest do
  use TidelandLedger.DataCase

  alias TidelandLedger.Templates
  alias TidelandLedger.Templates.{Template, TemplateLine}
  alias TidelandLedger.Amount

  describe "templates" do
    alias TidelandLedger.Templates.Template

    import TidelandLedger.Factory

    @valid_attrs %{
      name: "Monthly Rent",
      description: "Regular monthly rent payment",
      default_total: Decimal.new("1500.00"),
      lines: [
        %{
          # will be filled in setup
          account_id: nil,
          amount_type: :fixed,
          amount_value: Decimal.new("1500.00"),
          position: 1
        },
        %{
          # will be filled in setup
          account_id: nil,
          amount_type: :fixed,
          amount_value: Decimal.new("-1500.00"),
          position: 2
        }
      ],
      # will be filled in setup
      created_by_id: nil
    }
    @update_attrs %{
      description: "Updated monthly rent payment",
      default_total: Decimal.new("1600.00"),
      lines: [
        %{
          # will be filled in setup
          account_id: nil,
          amount_type: :fixed,
          amount_value: Decimal.new("1600.00"),
          position: 1
        },
        %{
          # will be filled in setup
          account_id: nil,
          amount_type: :fixed,
          amount_value: Decimal.new("-1600.00"),
          position: 2
        }
      ]
    }
    @invalid_attrs %{name: nil, lines: []}

    setup do
      user = insert(:user)
      expense_account = insert(:account, path: "Ausgaben : Büro : Miete")
      bank_account = insert(:account, path: "Vermögen : Bank : Girokonto")

      valid_attrs =
        @valid_attrs
        |> put_in([:created_by_id], user.id)
        |> put_in([:lines, 0, :account_id], expense_account.id)
        |> put_in([:lines, 1, :account_id], bank_account.id)

      update_attrs =
        @update_attrs
        |> put_in([:lines, 0, :account_id], expense_account.id)
        |> put_in([:lines, 1, :account_id], bank_account.id)

      %{
        user: user,
        expense_account: expense_account,
        bank_account: bank_account,
        valid_attrs: valid_attrs,
        update_attrs: update_attrs
      }
    end

    test "list_templates/0 returns all templates", %{valid_attrs: valid_attrs} do
      {:ok, template} = Templates.create_template(valid_attrs)
      templates = Templates.list_templates()
      assert length(templates) == 1
      assert hd(templates).id == template.id
    end

    test "get_template!/1 returns the template with given id", %{valid_attrs: valid_attrs} do
      {:ok, template} = Templates.create_template(valid_attrs)
      assert Templates.get_template!(template.id).id == template.id
    end

    test "create_template/1 with valid data creates a template", %{valid_attrs: valid_attrs} do
      assert {:ok, %Template{} = template} = Templates.create_template(valid_attrs)
      assert template.name == "Monthly Rent"
      assert template.description == "Regular monthly rent payment"
      assert Decimal.equal?(template.default_total, Decimal.new("1500.00"))
      assert template.version == 1
      assert length(template.lines) == 2
    end

    test "create_template/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Templates.create_template(@invalid_attrs)
    end

    test "create_new_version/2 creates a new version of a template", %{
      valid_attrs: valid_attrs,
      update_attrs: update_attrs
    } do
      {:ok, template} = Templates.create_template(valid_attrs)
      assert {:ok, %Template{} = new_version} = Templates.create_new_version(template, update_attrs)
      assert new_version.name == template.name
      assert new_version.version == template.version + 1
      assert new_version.description == "Updated monthly rent payment"
      assert Decimal.equal?(new_version.default_total, Decimal.new("1600.00"))
    end

    test "get_template_version/2 returns specific version of a template", %{
      valid_attrs: valid_attrs,
      update_attrs: update_attrs
    } do
      {:ok, template_v1} = Templates.create_template(valid_attrs)
      {:ok, template_v2} = Templates.create_new_version(template_v1, update_attrs)

      assert Templates.get_template_version("Monthly Rent", 1).id == template_v1.id
      assert Templates.get_template_version("Monthly Rent", 2).id == template_v2.id
      assert Templates.get_template_version("Monthly Rent", 3) == nil
    end

    test "get_latest_template/1 returns the latest version of a template", %{
      valid_attrs: valid_attrs,
      update_attrs: update_attrs
    } do
      {:ok, _template_v1} = Templates.create_template(valid_attrs)
      {:ok, template_v2} = Templates.create_new_version(%{name: "Monthly Rent", version: 1}, update_attrs)

      latest = Templates.get_latest_template("Monthly Rent")
      assert latest.id == template_v2.id
      assert latest.version == 2
    end

    test "list_template_versions/1 returns all versions of a template", %{
      valid_attrs: valid_attrs,
      update_attrs: update_attrs
    } do
      {:ok, template_v1} = Templates.create_template(valid_attrs)
      {:ok, template_v2} = Templates.create_new_version(template_v1, update_attrs)

      versions = Templates.list_template_versions("Monthly Rent")
      assert length(versions) == 2
      assert Enum.map(versions, & &1.version) |> Enum.sort() == [1, 2]
    end

    test "set_template_active/2 activates or deactivates a template", %{valid_attrs: valid_attrs} do
      {:ok, template} = Templates.create_template(valid_attrs)
      assert template.active == true

      {:ok, updated} = Templates.set_template_active(template, false)
      assert updated.active == false

      {:ok, reactivated} = Templates.set_template_active(updated, true)
      assert reactivated.active == true
    end

    test "apply_template/3 applies a fixed amount template", %{valid_attrs: valid_attrs} do
      {:ok, template} = Templates.create_template(valid_attrs)

      entry_attrs = %{
        date: ~D[2023-01-15],
        description: "January Rent Payment",
        created_by_id: template.created_by_id
      }

      {:ok, result} = Templates.apply_template(template, nil, entry_attrs)

      assert result.date == ~D[2023-01-15]
      assert result.description == "January Rent Payment"
      assert length(result.positions) == 2

      [pos1, pos2] = result.positions
      assert pos1.account_id == template.lines |> Enum.at(0) |> Map.get(:account_id)
      assert Amount.to_decimal(pos1.amount) |> Decimal.equal?(Decimal.new("1500.00"))

      assert pos2.account_id == template.lines |> Enum.at(1) |> Map.get(:account_id)
      assert Amount.to_decimal(pos2.amount) |> Decimal.equal?(Decimal.new("-1500.00"))
    end

    test "apply_template/3 applies a percentage-based template", %{
      user: user,
      expense_account: expense_account,
      bank_account: bank_account
    } do
      percentage_template = %{
        name: "Percentage Template",
        description: "Template with percentage distribution",
        lines: [
          %{
            account_id: expense_account.id,
            amount_type: :percentage,
            amount_value: Decimal.new("100.00"),
            position: 1
          },
          %{
            account_id: bank_account.id,
            amount_type: :percentage,
            amount_value: Decimal.new("-100.00"),
            position: 2
          }
        ],
        created_by_id: user.id
      }

      {:ok, template} = Templates.create_template(percentage_template)

      entry_attrs = %{
        date: ~D[2023-01-15],
        description: "Test Percentage",
        created_by_id: user.id
      }

      {:ok, result} = Templates.apply_template(template, Decimal.new("2000.00"), entry_attrs)

      assert length(result.positions) == 2

      [pos1, pos2] = result.positions
      assert Amount.to_decimal(pos1.amount) |> Decimal.equal?(Decimal.new("2000.00"))
      assert Amount.to_decimal(pos2.amount) |> Decimal.equal?(Decimal.new("-2000.00"))
    end

    test "apply_template_with_fractions/3 applies a template with fractions", %{
      user: user,
      expense_account: expense_account,
      bank_account: bank_account
    } do
      fraction_template = %{
        name: "Fraction Template",
        description: "Template with fractional distribution",
        lines: [
          %{
            account_id: expense_account.id,
            fraction: Decimal.new("0.70"),
            position: 1
          },
          %{
            account_id: bank_account.id,
            fraction: Decimal.new("-1.00"),
            position: 2
          }
        ],
        created_by_id: user.id
      }

      {:ok, template} = Templates.create_template(fraction_template)

      entry_attrs = %{
        date: ~D[2023-01-15],
        description: "Test Fractions",
        created_by_id: user.id
      }

      {:ok, result} = Templates.apply_template_with_fractions(template, Decimal.new("1000.00"), entry_attrs)

      assert length(result.positions) == 2

      [pos1, pos2] = result.positions
      assert Amount.to_decimal(pos1.amount) |> Decimal.equal?(Decimal.new("700.00"))
      assert Amount.to_decimal(pos2.amount) |> Decimal.equal?(Decimal.new("-1000.00"))
    end
  end
end
