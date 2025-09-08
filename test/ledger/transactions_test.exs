defmodule TidelandLedger.TransactionsTest do
  use TidelandLedger.DataCase, async: true

  alias TidelandLedger.Transactions
  alias TidelandLedger.Transactions.{Entry, Position}
  alias TidelandLedger.Accounts
  alias TidelandLedger.Accounts.Account
  alias TidelandLedger.Amount

  # Setup helpers
  # These create test data for our tests

  def create_test_accounts do
    # Create test accounts
    {:ok, cash} =
      Accounts.create_account(%{
        path: "Vermögen : Bargeld",
        description: "Cash on hand",
        created_by_id: 1
      })

    {:ok, bank} =
      Accounts.create_account(%{
        path: "Vermögen : Bank : Girokonto",
        description: "Checking account",
        created_by_id: 1
      })

    {:ok, expense} =
      Accounts.create_account(%{
        path: "Ausgaben : Büro : Material",
        description: "Office supplies",
        created_by_id: 1
      })

    {:ok, income} =
      Accounts.create_account(%{
        path: "Einnahmen : Arbeit : Freelance",
        description: "Freelance income",
        created_by_id: 1
      })

    %{cash: cash, bank: bank, expense: expense, income: income}
  end

  def valid_entry_attrs(accounts) do
    %{
      date: Date.utc_today(),
      description: "Purchase office supplies",
      reference: "INV-001",
      created_by_id: 1,
      positions: [
        %{
          account_id: accounts.expense.id,
          amount: Amount.new(50),
          description: "Paper and pens",
          position: 1
        },
        %{
          account_id: accounts.cash.id,
          amount: Amount.new(-50),
          description: "Cash payment",
          position: 2
        }
      ]
    }
  end

  describe "create_entry/1" do
    setup do
      accounts = create_test_accounts()
      {:ok, accounts: accounts}
    end

    test "creates entry with valid attributes", %{accounts: accounts} do
      attrs = valid_entry_attrs(accounts)

      assert {:ok, entry} = Transactions.create_entry(attrs)
      assert entry.description == "Purchase office supplies"
      assert entry.reference == "INV-001"
      assert entry.status == :draft
      assert length(entry.positions) == 2

      # Check positions
      expense_position = Enum.find(entry.positions, &(&1.account_id == accounts.expense.id))
      assert expense_position
      assert Amount.to_string(expense_position.amount) == "50,00 €"

      cash_position = Enum.find(entry.positions, &(&1.account_id == accounts.cash.id))
      assert cash_position
      assert Amount.to_string(cash_position.amount) == "-50,00 €"
    end

    test "fails with unbalanced positions", %{accounts: accounts} do
      attrs =
        valid_entry_attrs(accounts)
        |> put_in([:positions, 1, :amount], Amount.new(-40))

      assert {:error, changeset} = Transactions.create_entry(attrs)
      assert :transaction_not_balanced in errors_on(changeset).positions
    end

    test "fails with non-existent account", %{accounts: accounts} do
      attrs =
        valid_entry_attrs(accounts)
        |> put_in([:positions, 0, :account_id], 999_999)

      assert {:error, :accounts, {:accounts_not_found_or_inactive, [999_999]}} =
               Transactions.create_entry(attrs)
    end

    test "fails with inactive account", %{accounts: accounts} do
      # Deactivate an account
      {:ok, _} = Accounts.update_account(accounts.expense, %{active: false})

      attrs = valid_entry_attrs(accounts)

      assert {:error, :accounts, {:accounts_not_found_or_inactive, [accounts.expense.id]}} =
               Transactions.create_entry(attrs)
    end

    test "fails without required fields" do
      assert {:error, changeset} = Transactions.create_entry(%{})
      assert :required in errors_on(changeset).date
      assert :required in errors_on(changeset).description
      assert :required in errors_on(changeset).created_by_id
    end

    test "creates entry with multiple positions", %{accounts: accounts} do
      attrs = %{
        date: Date.utc_today(),
        description: "Complex transaction",
        created_by_id: 1,
        positions: [
          %{account_id: accounts.expense.id, amount: Amount.new(30), position: 1},
          %{account_id: accounts.income.id, amount: Amount.new(20), position: 2},
          %{account_id: accounts.bank.id, amount: Amount.new(-50), position: 3}
        ]
      }

      assert {:ok, entry} = Transactions.create_entry(attrs)
      assert length(entry.positions) == 3

      # Verify balance
      total =
        entry.positions
        |> Enum.map(& &1.amount)
        |> Amount.sum()

      assert Amount.zero?(total)
    end
  end

  describe "update_entry/2" do
    setup do
      accounts = create_test_accounts()
      {:ok, entry} = Transactions.create_entry(valid_entry_attrs(accounts))
      {:ok, accounts: accounts, entry: entry}
    end

    test "updates draft entry", %{entry: entry} do
      attrs = %{description: "Updated description", reference: "NEW-REF"}

      assert {:ok, updated_entry} = Transactions.update_entry(entry, attrs)
      assert updated_entry.description == "Updated description"
      assert updated_entry.reference == "NEW-REF"
    end

    test "cannot update posted entry", %{entry: entry} do
      {:ok, posted_entry} = Transactions.post_entry(entry, 1)

      assert {:error, :entry_not_editable} =
               Transactions.update_entry(posted_entry, %{description: "New"})
    end

    test "updates positions", %{entry: entry, accounts: accounts} do
      attrs = %{
        positions: [
          %{account_id: accounts.expense.id, amount: Amount.new(75), position: 1},
          %{account_id: accounts.bank.id, amount: Amount.new(-75), position: 2}
        ]
      }

      assert {:ok, updated_entry} = Transactions.update_entry(entry, attrs)
      assert length(updated_entry.positions) == 2

      expense_pos = Enum.find(updated_entry.positions, &(&1.account_id == accounts.expense.id))
      assert Amount.to_string(expense_pos.amount) == "75,00 €"
    end

    test "validates balance on update", %{entry: entry, accounts: accounts} do
      attrs = %{
        positions: [
          %{account_id: accounts.expense.id, amount: Amount.new(75), position: 1},
          %{account_id: accounts.bank.id, amount: Amount.new(-50), position: 2}
        ]
      }

      assert {:error, changeset} = Transactions.update_entry(entry, attrs)
      assert :transaction_not_balanced in errors_on(changeset).positions
    end
  end

  describe "delete_entry/1" do
    setup do
      accounts = create_test_accounts()
      {:ok, entry} = Transactions.create_entry(valid_entry_attrs(accounts))
      {:ok, entry: entry}
    end

    test "deletes draft entry", %{entry: entry} do
      assert {:ok, deleted_entry} = Transactions.delete_entry(entry)
      assert deleted_entry.id == entry.id
      assert Transactions.get_entry(entry.id) == nil
    end

    test "cannot delete posted entry", %{entry: entry} do
      {:ok, posted_entry} = Transactions.post_entry(entry, 1)

      assert {:error, :entry_not_deletable} = Transactions.delete_entry(posted_entry)
      assert Transactions.get_entry(posted_entry.id) != nil
    end
  end

  describe "post_entry/2" do
    setup do
      accounts = create_test_accounts()
      {:ok, entry} = Transactions.create_entry(valid_entry_attrs(accounts))
      {:ok, accounts: accounts, entry: entry}
    end

    test "posts draft entry", %{entry: entry} do
      assert {:ok, posted_entry} = Transactions.post_entry(entry, 1)
      assert posted_entry.status == :posted
      assert posted_entry.posted_by_id == 1
      assert posted_entry.posted_at != nil
    end

    test "cannot post already posted entry", %{entry: entry} do
      {:ok, posted_entry} = Transactions.post_entry(entry, 1)

      assert {:error, :already_posted} = Transactions.post_entry(posted_entry, 1)
    end

    test "cannot post entry with inactive account", %{entry: entry, accounts: accounts} do
      # Deactivate account after entry creation
      {:ok, _} = Accounts.update_account(accounts.expense, %{active: false})

      assert {:error, :accounts, {:inactive_accounts, ["Ausgaben : Büro : Material"]}} =
               Transactions.post_entry(entry, 1)
    end
  end

  describe "void_entry/3" do
    setup do
      accounts = create_test_accounts()
      {:ok, entry} = Transactions.create_entry(valid_entry_attrs(accounts))
      {:ok, posted_entry} = Transactions.post_entry(entry, 1)
      {:ok, accounts: accounts, entry: posted_entry}
    end

    test "voids posted entry", %{entry: entry} do
      assert {:ok, {voided_entry, reversal_entry}} =
               Transactions.void_entry(entry, 1, "Duplicate transaction")

      assert voided_entry.status == :void
      assert voided_entry.voided_by_id == 1
      assert voided_entry.void_reason == "Duplicate transaction"
      assert voided_entry.voided_at != nil

      # Check reversal entry
      assert reversal_entry.status == :posted
      assert reversal_entry.description =~ "Storno:"
      assert length(reversal_entry.positions) == length(entry.positions)

      # Verify reversal amounts
      original_sum =
        entry.positions
        |> Enum.map(& &1.amount)
        |> Amount.sum()

      reversal_sum =
        reversal_entry.positions
        |> Enum.map(& &1.amount)
        |> Amount.sum()

      assert Amount.zero?(original_sum)
      assert Amount.zero?(reversal_sum)
    end

    test "cannot void draft entry", %{accounts: accounts} do
      {:ok, draft_entry} = Transactions.create_entry(valid_entry_attrs(accounts))

      assert {:error, :not_posted} = Transactions.void_entry(draft_entry, 1, "Reason")
    end

    test "cannot void already voided entry", %{entry: entry} do
      {:ok, {voided_entry, _}} = Transactions.void_entry(entry, 1, "First void")

      assert {:error, :not_posted} = Transactions.void_entry(voided_entry, 1, "Second void")
    end

    test "requires void reason", %{entry: entry} do
      assert {:error, changeset} = Transactions.void_entry(entry, 1, "")
      assert :required in errors_on(changeset).void_reason
    end
  end

  describe "list_entries/1" do
    setup do
      accounts = create_test_accounts()

      # Create multiple entries
      {:ok, draft1} =
        Transactions.create_entry(
          valid_entry_attrs(accounts)
          |> Map.put(:description, "Draft entry 1")
          |> Map.put(:date, ~D[2024-01-15])
        )

      {:ok, draft2} =
        Transactions.create_entry(
          valid_entry_attrs(accounts)
          |> Map.put(:description, "Draft entry 2")
          |> Map.put(:date, ~D[2024-01-20])
        )

      {:ok, posted1} =
        valid_entry_attrs(accounts)
        |> Map.put(:description, "Posted entry 1")
        |> Map.put(:date, ~D[2024-01-10])
        |> Transactions.create_entry()

      {:ok, posted1} = Transactions.post_entry(posted1, 1)

      {:ok, posted2} =
        valid_entry_attrs(accounts)
        |> Map.put(:description, "Invoice payment")
        |> Map.put(:reference, "INV-2024-001")
        |> Map.put(:date, ~D[2024-01-25])
        |> Transactions.create_entry()

      {:ok, posted2} = Transactions.post_entry(posted2, 1)

      {:ok, accounts: accounts, entries: [draft1, draft2, posted1, posted2]}
    end

    test "lists all entries", %{entries: entries} do
      result = Transactions.list_entries()
      assert length(result) == length(entries)
    end

    test "filters by status", %{} do
      draft_entries = Transactions.list_entries(status: :draft)
      assert length(draft_entries) == 2
      assert Enum.all?(draft_entries, &(&1.status == :draft))

      posted_entries = Transactions.list_entries(status: :posted)
      assert length(posted_entries) == 2
      assert Enum.all?(posted_entries, &(&1.status == :posted))
    end

    test "filters by date range", %{} do
      entries = Transactions.list_entries(from_date: ~D[2024-01-15], to_date: ~D[2024-01-20])
      assert length(entries) == 2
      assert Enum.all?(entries, &(&1.date >= ~D[2024-01-15] and &1.date <= ~D[2024-01-20]))
    end

    test "searches by description and reference", %{} do
      entries = Transactions.list_entries(search: "Invoice")
      assert length(entries) == 1
      assert hd(entries).description == "Invoice payment"

      entries = Transactions.list_entries(search: "INV-2024")
      assert length(entries) == 1
      assert hd(entries).reference == "INV-2024-001"
    end

    test "filters by account", %{accounts: accounts} do
      entries = Transactions.list_entries(account_id: accounts.expense.id)
      assert length(entries) == 4
      # All test entries use the expense account
    end

    test "applies limit and offset", %{} do
      entries = Transactions.list_entries(limit: 2)
      assert length(entries) == 2

      entries = Transactions.list_entries(limit: 2, offset: 2)
      assert length(entries) == 2
    end

    test "orders by date descending", %{} do
      entries = Transactions.list_entries()
      dates = Enum.map(entries, & &1.date)

      assert dates == Enum.sort(dates, &(Date.compare(&1, &2) != :lt))
    end
  end

  describe "get_entry/1" do
    setup do
      accounts = create_test_accounts()
      {:ok, entry} = Transactions.create_entry(valid_entry_attrs(accounts))
      {:ok, entry: entry}
    end

    test "returns entry by id", %{entry: entry} do
      found = Transactions.get_entry(entry.id)
      assert found.id == entry.id
      assert found.description == entry.description
    end

    test "returns nil for non-existent id" do
      assert Transactions.get_entry(999_999) == nil
    end

    test "preloads associations", %{entry: entry} do
      found = Transactions.get_entry(entry.id, preload: [:positions])
      assert length(found.positions) == 2
      refute match?(%Ecto.Association.NotLoaded{}, found.positions)
    end
  end

  describe "list_positions_for_account/2" do
    setup do
      accounts = create_test_accounts()

      # Create and post entries
      {:ok, entry1} =
        valid_entry_attrs(accounts)
        |> Map.put(:date, ~D[2024-01-10])
        |> Transactions.create_entry()

      {:ok, entry1} = Transactions.post_entry(entry1, 1)

      {:ok, entry2} =
        valid_entry_attrs(accounts)
        |> Map.put(:date, ~D[2024-01-20])
        |> Transactions.create_entry()

      {:ok, entry2} = Transactions.post_entry(entry2, 1)

      # Create draft entry
      {:ok, _draft} =
        valid_entry_attrs(accounts)
        |> Map.put(:date, ~D[2024-01-15])
        |> Transactions.create_entry()

      {:ok, accounts: accounts, entries: [entry1, entry2]}
    end

    test "lists positions for account", %{accounts: accounts} do
      positions = Transactions.list_positions_for_account(accounts.expense.id)
      # 2 posted + 1 draft
      assert length(positions) == 3
    end

    test "filters posted only", %{accounts: accounts} do
      positions = Transactions.list_positions_for_account(accounts.expense.id, posted_only: true)
      assert length(positions) == 2
      assert Enum.all?(positions, &(&1.entry.status == :posted))
    end

    test "filters by date range", %{accounts: accounts} do
      positions =
        Transactions.list_positions_for_account(accounts.expense.id,
          from_date: ~D[2024-01-15],
          to_date: ~D[2024-01-25],
          posted_only: true
        )

      assert length(positions) == 1
      assert hd(positions).entry.date == ~D[2024-01-20]
    end
  end

  describe "get_account_balance/2" do
    setup do
      accounts = create_test_accounts()

      # Create entries with different dates
      {:ok, entry1} =
        %{
          date: ~D[2024-01-10],
          description: "Income",
          created_by_id: 1,
          positions: [
            %{account_id: accounts.bank.id, amount: Amount.new(1000), position: 1},
            %{account_id: accounts.income.id, amount: Amount.new(-1000), position: 2}
          ]
        }
        |> Transactions.create_entry()

      {:ok, entry1} = Transactions.post_entry(entry1, 1)

      {:ok, entry2} =
        %{
          date: ~D[2024-01-20],
          description: "Expense",
          created_by_id: 1,
          positions: [
            %{account_id: accounts.expense.id, amount: Amount.new(200), position: 1},
            %{account_id: accounts.bank.id, amount: Amount.new(-200), position: 2}
          ]
        }
        |> Transactions.create_entry()

      {:ok, entry2} = Transactions.post_entry(entry2, 1)

      # Create draft entry (should not affect balance)
      {:ok, _draft} =
        %{
          date: ~D[2024-01-25],
          description: "Draft expense",
          created_by_id: 1,
          positions: [
            %{account_id: accounts.expense.id, amount: Amount.new(100), position: 1},
            %{account_id: accounts.bank.id, amount: Amount.new(-100), position: 2}
          ]
        }
        |> Transactions.create_entry()

      {:ok, accounts: accounts}
    end

    test "calculates current balance", %{accounts: accounts} do
      balance = Transactions.get_account_balance(accounts.bank.id)
      # 1000 - 200
      assert Amount.to_string(balance) == "800,00 €"
    end

    test "calculates balance as of date", %{accounts: accounts} do
      balance = Transactions.get_account_balance(accounts.bank.id, ~D[2024-01-15])
      # Only first entry
      assert Amount.to_string(balance) == "1.000,00 €"

      balance = Transactions.get_account_balance(accounts.bank.id, ~D[2024-01-30])
      # Both entries
      assert Amount.to_string(balance) == "800,00 €"
    end

    test "returns zero for account with no transactions", %{accounts: accounts} do
      balance = Transactions.get_account_balance(accounts.cash.id)
      assert Amount.zero?(balance)
    end

    test "ignores draft entries", %{accounts: accounts} do
      balance_before = Transactions.get_account_balance(accounts.bank.id, ~D[2024-01-25])
      balance_after = Transactions.get_account_balance(accounts.bank.id, ~D[2024-01-30])

      assert Amount.compare(balance_before, balance_after) == :eq
    end
  end

  describe "trial_balance/1" do
    setup do
      accounts = create_test_accounts()

      # Create and post some entries
      {:ok, entry1} =
        %{
          date: ~D[2024-01-10],
          description: "Income",
          created_by_id: 1,
          positions: [
            %{account_id: accounts.bank.id, amount: Amount.new(1000), position: 1},
            %{account_id: accounts.income.id, amount: Amount.new(-1000), position: 2}
          ]
        }
        |> Transactions.create_entry()

      {:ok, _} = Transactions.post_entry(entry1, 1)

      {:ok, entry2} =
        %{
          date: ~D[2024-01-20],
          description: "Transfer to cash",
          created_by_id: 1,
          positions: [
            %{account_id: accounts.cash.id, amount: Amount.new(200), position: 1},
            %{account_id: accounts.bank.id, amount: Amount.new(-200), position: 2}
          ]
        }
        |> Transactions.create_entry()

      {:ok, _} = Transactions.post_entry(entry2, 1)

      {:ok, accounts: accounts}
    end

    test "generates trial balance", %{accounts: accounts} do
      balances = Transactions.trial_balance(~D[2024-01-31])

      # Find specific accounts in the balance
      bank_balance = Enum.find(balances, &(&1.account.id == accounts.bank.id))
      cash_balance = Enum.find(balances, &(&1.account.id == accounts.cash.id))
      income_balance = Enum.find(balances, &(&1.account.id == accounts.income.id))

      assert bank_balance
      assert Amount.to_string(bank_balance.balance) == "800,00 €"
      assert Amount.to_string(bank_balance.debit) == "1.000,00 €"
      assert Amount.to_string(bank_balance.credit) == "200,00 €"

      assert cash_balance
      assert Amount.to_string(cash_balance.balance) == "200,00 €"

      assert income_balance
      assert Amount.to_string(income_balance.balance) == "-1.000,00 €"
    end

    test "filters by date", %{accounts: accounts} do
      balances = Transactions.trial_balance(~D[2024-01-15])

      # Should only include first entry
      bank_balance = Enum.find(balances, &(&1.account.id == accounts.bank.id))
      assert Amount.to_string(bank_balance.balance) == "1.000,00 €"

      # Cash should not appear (no transactions before this date)
      cash_balance = Enum.find(balances, &(&1.account.id == accounts.cash.id))
      refute cash_balance
    end

    test "excludes accounts with zero balance" do
      balances = Transactions.trial_balance()

      # All accounts in the balance should have non-zero balance
      assert Enum.all?(balances, fn %{balance: balance} ->
               not Amount.zero?(balance)
             end)
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
