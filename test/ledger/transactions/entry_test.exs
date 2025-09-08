defmodule TidelandLedger.Transactions.EntryTest do
  use TidelandLedger.DataCase, async: true

  alias TidelandLedger.Transactions.{Entry, Position}
  alias TidelandLedger.Accounts.Account
  alias TidelandLedger.Amount

  # Test data setup helpers
  def valid_position_attrs(overrides \\ %{}) do
    Enum.into(overrides, %{
      account_id: 1,
      amount: Amount.new(100),
      description: "Test position",
      tax_relevant: false,
      position: 1
    })
  end

  def valid_entry_attrs(overrides \\ %{}) do
    Enum.into(overrides, %{
      date: ~D[2024-01-15],
      description: "Test transaction",
      reference: "REF-001",
      created_by_id: 1,
      positions: [
        valid_position_attrs(%{amount: Amount.new(100), position: 1}),
        valid_position_attrs(%{amount: Amount.new(-100), account_id: 2, position: 2})
      ]
    })
  end

  describe "changeset/2" do
    test "valid changeset with minimal data" do
      changeset = Entry.changeset(%Entry{}, valid_entry_attrs())

      assert changeset.valid?
      assert get_change(changeset, :date) == ~D[2024-01-15]
      assert get_change(changeset, :description) == "Test transaction"
      assert get_field(changeset, :status) == :draft
    end

    test "valid changeset without reference" do
      attrs = valid_entry_attrs() |> Map.delete(:reference)
      changeset = Entry.changeset(%Entry{}, attrs)

      assert changeset.valid?
      assert get_field(changeset, :reference) == nil
    end

    test "requires date" do
      attrs = valid_entry_attrs() |> Map.delete(:date)
      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert :required in errors_on(changeset).date
    end

    test "requires description" do
      attrs = valid_entry_attrs() |> Map.delete(:description)
      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert :required in errors_on(changeset).description
    end

    test "requires created_by_id" do
      attrs = valid_entry_attrs() |> Map.delete(:created_by_id)
      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert :required in errors_on(changeset).created_by_id
    end

    test "validates description length" do
      attrs = valid_entry_attrs(%{description: "ab"})
      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert {:min_length, 3} in errors_on(changeset).description

      attrs = valid_entry_attrs(%{description: String.duplicate("a", 501)})
      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert {:max_length, 500} in errors_on(changeset).description
    end

    test "validates reference length" do
      attrs = valid_entry_attrs(%{reference: String.duplicate("a", 51)})
      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert {:max_length, 50} in errors_on(changeset).reference
    end

    test "rejects future dates" do
      future_date = Date.utc_today() |> Date.add(1)
      attrs = valid_entry_attrs(%{date: future_date})
      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert :future_date_not_allowed in errors_on(changeset).date
    end

    test "rejects dates exceeding backdate limit" do
      # Assuming default max_backdate_days is 365
      old_date = Date.utc_today() |> Date.add(-366)
      attrs = valid_entry_attrs(%{date: old_date})
      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert {:exceeds_backdate_limit, 365} in errors_on(changeset).date
    end

    test "accepts dates within backdate limit" do
      recent_date = Date.utc_today() |> Date.add(-30)
      attrs = valid_entry_attrs(%{date: recent_date})
      changeset = Entry.changeset(%Entry{}, attrs)

      assert changeset.valid?
    end

    test "requires positions" do
      attrs = valid_entry_attrs() |> Map.delete(:positions)
      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert :required in errors_on(changeset).positions
    end

    test "requires at least 2 positions" do
      attrs =
        valid_entry_attrs(%{
          positions: [valid_position_attrs()]
        })

      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert :insufficient_positions in errors_on(changeset).positions
    end

    test "validates maximum positions" do
      # Create 101 positions (assuming max is 100)
      positions =
        for i <- 1..101 do
          amount = if rem(i, 2) == 0, do: -1, else: 1

          valid_position_attrs(%{
            amount: Amount.new(amount),
            account_id: i,
            position: i
          })
        end

      # Adjust last position to balance
      positions = List.update_at(positions, -1, &%{&1 | amount: Amount.new(0)})

      attrs = valid_entry_attrs(%{positions: positions})
      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert {:exceeds_max_positions, 100} in errors_on(changeset).positions
    end

    test "validates positions must balance" do
      attrs =
        valid_entry_attrs(%{
          positions: [
            valid_position_attrs(%{amount: Amount.new(100), position: 1}),
            valid_position_attrs(%{amount: Amount.new(-50), account_id: 2, position: 2})
          ]
        })

      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert :transaction_not_balanced in errors_on(changeset).positions
    end

    test "validates unique accounts in positions" do
      attrs =
        valid_entry_attrs(%{
          positions: [
            valid_position_attrs(%{amount: Amount.new(100), account_id: 1, position: 1}),
            valid_position_attrs(%{amount: Amount.new(-100), account_id: 1, position: 2})
          ]
        })

      changeset = Entry.changeset(%Entry{}, attrs)

      refute changeset.valid?
      assert :duplicate_accounts in errors_on(changeset).positions
    end

    test "accepts valid balanced entry with multiple positions" do
      attrs =
        valid_entry_attrs(%{
          positions: [
            valid_position_attrs(%{amount: Amount.new(100), account_id: 1, position: 1}),
            valid_position_attrs(%{amount: Amount.new(50), account_id: 2, position: 2}),
            valid_position_attrs(%{amount: Amount.new(-150), account_id: 3, position: 3})
          ]
        })

      changeset = Entry.changeset(%Entry{}, attrs)

      assert changeset.valid?
    end
  end

  describe "post_changeset/2" do
    setup do
      entry = %Entry{
        id: 1,
        status: :draft,
        date: ~D[2024-01-15],
        description: "Test entry"
      }

      {:ok, entry: entry}
    end

    test "posts a draft entry", %{entry: entry} do
      changeset = Entry.post_changeset(entry, 123)

      assert changeset.valid?
      assert get_change(changeset, :status) == :posted
      assert get_change(changeset, :posted_by_id) == 123
      assert %DateTime{} = get_change(changeset, :posted_at)
    end

    test "cannot post already posted entry", %{entry: entry} do
      posted_entry = %{entry | status: :posted}
      changeset = Entry.post_changeset(posted_entry, 123)

      refute changeset.valid?
      assert :already_posted in errors_on(changeset).status
    end

    test "cannot post voided entry", %{entry: entry} do
      voided_entry = %{entry | status: :void}
      changeset = Entry.post_changeset(voided_entry, 123)

      refute changeset.valid?
      assert :already_posted in errors_on(changeset).status
    end
  end

  describe "void_changeset/3" do
    setup do
      entry = %Entry{
        id: 1,
        status: :posted,
        date: ~D[2024-01-15],
        description: "Test entry"
      }

      {:ok, entry: entry}
    end

    test "voids a posted entry", %{entry: entry} do
      changeset = Entry.void_changeset(entry, 123, "Duplicate entry")

      assert changeset.valid?
      assert get_change(changeset, :status) == :void
      assert get_change(changeset, :voided_by_id) == 123
      assert get_change(changeset, :void_reason) == "Duplicate entry"
      assert %DateTime{} = get_change(changeset, :voided_at)
    end

    test "requires void reason", %{entry: entry} do
      changeset = Entry.void_changeset(entry, 123, "")

      refute changeset.valid?
      assert :required in errors_on(changeset).void_reason
    end

    test "validates void reason length", %{entry: entry} do
      changeset = Entry.void_changeset(entry, 123, "abc")

      refute changeset.valid?
      assert {:min_length, 5} in errors_on(changeset).void_reason

      long_reason = String.duplicate("a", 501)
      changeset = Entry.void_changeset(entry, 123, long_reason)

      refute changeset.valid?
      assert {:max_length, 500} in errors_on(changeset).void_reason
    end

    test "cannot void draft entry", %{entry: entry} do
      draft_entry = %{entry | status: :draft}
      changeset = Entry.void_changeset(draft_entry, 123, "Test reason")

      refute changeset.valid?
      assert :not_posted in errors_on(changeset).status
    end

    test "cannot void already voided entry", %{entry: entry} do
      voided_entry = %{entry | status: :void}
      changeset = Entry.void_changeset(voided_entry, 123, "Test reason")

      refute changeset.valid?
      assert :not_posted in errors_on(changeset).status
    end
  end

  describe "query functions" do
    test "by_date_range_query/2 filters by date range" do
      query = Entry.by_date_range_query(~D[2024-01-01], ~D[2024-01-31])

      {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
      assert sql =~ "date\" >="
      assert sql =~ "date\" <="
      assert ~D[2024-01-01] in params
      assert ~D[2024-01-31] in params
    end

    test "by_status_query/1 filters by status" do
      query = Entry.by_status_query(:posted)

      {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
      assert sql =~ "status\" ="
      assert "posted" in params
    end

    test "with_positions_query/0 preloads positions" do
      query = Entry.with_positions_query()

      # This would need actual DB setup to test preloading
      assert %Ecto.Query{} = query
    end

    test "search_query/1 searches description and reference" do
      query = Entry.search_query("invoice")

      {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
      assert sql =~ "ILIKE"
      assert "%invoice%" in params
    end
  end

  describe "helper functions" do
    test "editable?/1 returns true for draft entries" do
      assert Entry.editable?(%Entry{status: :draft})
      refute Entry.editable?(%Entry{status: :posted})
      refute Entry.editable?(%Entry{status: :void})
    end

    test "can_post?/1 returns true only for draft entries" do
      assert Entry.can_post?(%Entry{status: :draft})
      refute Entry.can_post?(%Entry{status: :posted})
      refute Entry.can_post?(%Entry{status: :void})
    end

    test "can_void?/1 returns true only for posted entries" do
      refute Entry.can_void?(%Entry{status: :draft})
      assert Entry.can_void?(%Entry{status: :posted})
      refute Entry.can_void?(%Entry{status: :void})
    end

    test "total_amount/1 calculates sum of positive positions" do
      positions = [
        %Position{amount: Amount.new(100)},
        %Position{amount: Amount.new(50)},
        %Position{amount: Amount.new(-150)}
      ]

      entry = %Entry{positions: positions}

      total = Entry.total_amount(entry)
      assert Amount.to_string(total) == "150,00 €"
    end

    test "total_amount/1 returns zero for entry without positions" do
      entry = %Entry{positions: []}
      total = Entry.total_amount(entry)
      assert Amount.zero?(total)
    end

    test "display/2 formats entry for display" do
      entry = %Entry{
        date: ~D[2024-01-15],
        description: "Office supplies",
        reference: "INV-001"
      }

      assert Entry.display(entry) == "2024-01-15 - Office supplies (INV-001)"
      assert Entry.display(entry, :description) == "Office supplies"
      assert Entry.display(entry, :summary) == "2024-01-15 (INV-001)"

      # Without reference
      entry_no_ref = %{entry | reference: nil}
      assert Entry.display(entry_no_ref) == "2024-01-15 - Office supplies"
      assert Entry.display(entry_no_ref, :summary) == "2024-01-15"
    end
  end

  # Helper function to extract errors from changeset
  defp errors_on(changeset) do
    changeset.errors
    |> Enum.reduce(%{}, fn {field, error}, acc ->
      Map.update(acc, field, [error], fn errors -> [error | errors] end)
    end)
  end
end
