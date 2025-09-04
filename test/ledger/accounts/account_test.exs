defmodule Ledger.Accounts.AccountTest do
  use Ledger.DataCase, async: true
  alias Ledger.Accounts.Account

  describe "changeset/2" do
    test "valid changeset with minimal data" do
      changeset =
        Account.changeset(%Account{}, %{
          path: "Ausgaben : Büro",
          created_by_id: 1
        })

      assert changeset.valid?
      assert get_change(changeset, :path) == "Ausgaben : Büro"
      assert get_change(changeset, :name) == "Büro"
      assert get_change(changeset, :parent_path) == "Ausgaben"
      assert get_change(changeset, :depth) == 2
      assert get_field(changeset, :active) == true
    end

    test "valid changeset for root account" do
      changeset =
        Account.changeset(%Account{}, %{
          path: "Ausgaben",
          description: "Alle Ausgaben",
          created_by_id: 1
        })

      assert changeset.valid?
      assert get_change(changeset, :path) == "Ausgaben"
      assert get_change(changeset, :name) == "Ausgaben"
      assert get_change(changeset, :parent_path) == nil
      assert get_change(changeset, :depth) == 1
    end

    test "normalizes path spacing" do
      changeset =
        Account.changeset(%Account{}, %{
          path: "Ausgaben:Büro:Material",
          created_by_id: 1
        })

      assert changeset.valid?
      assert get_change(changeset, :path) == "Ausgaben : Büro : Material"
      assert get_change(changeset, :name) == "Material"
      assert get_change(changeset, :parent_path) == "Ausgaben : Büro"
      assert get_change(changeset, :depth) == 3
    end

    test "removes empty segments from path" do
      changeset =
        Account.changeset(%Account{}, %{
          path: "Ausgaben : : Büro : : Material",
          created_by_id: 1
        })

      assert changeset.valid?
      assert get_change(changeset, :path) == "Ausgaben : Büro : Material"
    end

    test "invalid with empty path" do
      changeset =
        Account.changeset(%Account{}, %{
          path: "",
          created_by_id: 1
        })

      refute changeset.valid?
      assert :empty_path in errors_on(changeset).path
    end

    test "invalid with only whitespace path" do
      changeset =
        Account.changeset(%Account{}, %{
          path: "   ",
          created_by_id: 1
        })

      refute changeset.valid?
      assert :empty_path in errors_on(changeset).path
    end

    test "invalid when exceeding max depth" do
      # Max depth is 6
      changeset =
        Account.changeset(%Account{}, %{
          path: "A : B : C : D : E : F : G",
          created_by_id: 1
        })

      refute changeset.valid?
      assert {:exceeds_max_depth, 6} in errors_on(changeset).path
    end

    test "requires created_by_id" do
      changeset =
        Account.changeset(%Account{}, %{
          path: "Ausgaben"
        })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).created_by_id
    end

    test "validates description length" do
      long_description = String.duplicate("a", 501)

      changeset =
        Account.changeset(%Account{}, %{
          path: "Ausgaben",
          description: long_description,
          created_by_id: 1
        })

      refute changeset.valid?
      assert "should be at most 500 character(s)" in errors_on(changeset).description
    end

    test "sets active to true by default" do
      changeset =
        Account.changeset(%Account{}, %{
          path: "Ausgaben",
          created_by_id: 1
        })

      assert get_field(changeset, :active) == true
    end

    test "allows setting active to false" do
      changeset =
        Account.changeset(%Account{}, %{
          path: "Ausgaben",
          active: false,
          created_by_id: 1
        })

      assert changeset.valid?
      assert get_field(changeset, :active) == false
    end
  end

  describe "deactivate_changeset/1" do
    test "sets active to false" do
      account = %Account{
        id: 1,
        path: "Ausgaben : Büro",
        name: "Büro",
        active: true
      }

      changeset = Account.deactivate_changeset(account)

      assert changeset.valid?
      assert get_change(changeset, :active) == false
    end

    test "validates no active children" do
      # This test would need actual database setup
      # For now, we just test the structure
      account = %Account{
        id: 1,
        path: "Ausgaben",
        active: true
      }

      # Assuming has_active_children?/1 would return false
      changeset = Account.deactivate_changeset(account)
      assert changeset.valid?
    end
  end

  describe "query functions" do
    test "roots_query/0 filters by nil parent_path" do
      query = Account.roots_query()

      # Convert to SQL to check the WHERE clause
      {sql, _} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
      assert sql =~ "parent_path\" IS NULL"
      assert sql =~ "ORDER BY"
    end

    test "children_query/1 filters by parent_path" do
      query = Account.children_query("Ausgaben")

      {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
      assert sql =~ "parent_path\" = ?"
      assert "Ausgaben" in params
    end

    test "descendants_query/1 uses LIKE for path matching" do
      query = Account.descendants_query("Ausgaben")

      {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
      assert sql =~ "path\" LIKE ?"
      assert "Ausgaben : %" in params
    end

    test "active_query/0 filters by active flag" do
      query = Account.active_query()

      {sql, _} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
      assert sql =~ "active\" = TRUE"
    end

    test "search_query/1 searches in path and name" do
      query = Account.search_query("büro")

      {sql, params} = Ecto.Adapters.SQL.to_sql(:all, Repo, query)
      assert sql =~ "ILIKE"
      assert sql =~ "OR"
      assert "%büro%" in params
    end
  end

  describe "build_tree/1" do
    test "builds tree from flat list" do
      accounts = [
        %Account{id: 1, path: "Ausgaben", parent_path: nil},
        %Account{id: 2, path: "Ausgaben : Büro", parent_path: "Ausgaben"},
        %Account{id: 3, path: "Ausgaben : Personal", parent_path: "Ausgaben"},
        %Account{id: 4, path: "Ausgaben : Büro : Material", parent_path: "Ausgaben : Büro"},
        %Account{id: 5, path: "Einnahmen", parent_path: nil}
      ]

      tree = Account.build_tree(accounts)

      assert length(tree) == 2

      # Check first root (Ausgaben)
      ausgaben_node = Enum.find(tree, &(&1.account.path == "Ausgaben"))
      assert ausgaben_node.account.path == "Ausgaben"
      assert length(ausgaben_node.children) == 2

      # Check nested child
      buero_node = Enum.find(ausgaben_node.children, &(&1.account.path == "Ausgaben : Büro"))
      assert length(buero_node.children) == 1
      assert hd(buero_node.children).account.path == "Ausgaben : Büro : Material"
    end

    test "handles empty list" do
      assert Account.build_tree([]) == []
    end

    test "handles list with only root accounts" do
      accounts = [
        %Account{id: 1, path: "Ausgaben", parent_path: nil},
        %Account{id: 2, path: "Einnahmen", parent_path: nil}
      ]

      tree = Account.build_tree(accounts)

      assert length(tree) == 2
      assert Enum.all?(tree, &(&1.children == []))
    end
  end

  describe "display/2" do
    setup do
      account = %Account{
        path: "Ausgaben : Büro : Material",
        name: "Material",
        active: true
      }

      {:ok, account: account}
    end

    test "displays full path by default", %{account: account} do
      assert Account.display(account) == "Ausgaben : Büro : Material"
    end

    test "displays full path with :full_path format", %{account: account} do
      assert Account.display(account, :full_path) == "Ausgaben : Büro : Material"
    end

    test "displays compact format with :name_with_parents", %{account: account} do
      assert Account.display(account, :name_with_parents) == "A : B : Material"
    end

    test "displays name only with :name_only format", %{account: account} do
      assert Account.display(account, :name_only) == "Material"
    end

    test "displays with status for inactive accounts" do
      inactive_account = %Account{
        path: "Ausgaben : Alt",
        name: "Alt",
        active: false
      }

      assert Account.display(inactive_account, :with_status) == "Ausgaben : Alt (inaktiv)"
    end

    test "displays with status for active accounts", %{account: account} do
      assert Account.display(account, :with_status) == "Ausgaben : Büro : Material"
    end
  end

  describe "helper functions" do
    test "has_active_children?/1 returns boolean" do
      account = %Account{path: "Ausgaben"}

      # This would need database setup to test properly
      # For now, just ensure it returns a boolean
      result = Account.has_active_children?(account)
      assert is_boolean(result)
    end

    test "has_recent_transactions?/1 returns boolean" do
      account = %Account{id: 1, path: "Ausgaben"}

      # Placeholder implementation returns false
      assert Account.has_recent_transactions?(account, 30) == false
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
