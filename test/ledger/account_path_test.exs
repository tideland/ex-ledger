defmodule TidelandLedger.AccountPathTest do
  use ExUnit.Case, async: true
  doctest TidelandLedger.AccountPath

  alias TidelandLedger.AccountPath

  describe "normalize/1" do
    test "normalizes standard path" do
      assert AccountPath.normalize("Ausgaben:Büro:Material") == "Ausgaben : Büro : Material"
    end

    test "handles extra spaces" do
      assert AccountPath.normalize("Ausgaben  :  Büro  :   Material") == "Ausgaben : Büro : Material"
    end

    test "removes empty segments" do
      assert AccountPath.normalize("Ausgaben : : Büro : Material") == "Ausgaben : Büro : Material"
    end

    test "handles single segment" do
      assert AccountPath.normalize("Ausgaben") == "Ausgaben"
    end

    test "handles empty string" do
      assert AccountPath.normalize("") == ""
    end
  end

  describe "valid?/1" do
    test "validates correct paths" do
      assert AccountPath.valid?("Ausgaben")
      assert AccountPath.valid?("Ausgaben : Büro")
      assert AccountPath.valid?("Ausgaben : Büro : Material")
    end

    test "rejects empty path" do
      refute AccountPath.valid?("")
    end

    test "rejects paths exceeding max depth" do
      # Assuming max depth of 6
      deep_path = Enum.join(1..7 |> Enum.map(&"Level#{&1}"), " : ")
      refute AccountPath.valid?(deep_path)
    end
  end

  describe "validate/1" do
    test "returns :ok for valid paths" do
      assert AccountPath.validate("Ausgaben : Büro") == :ok
    end

    test "returns error for empty path" do
      assert AccountPath.validate("") == {:error, :empty_path}
    end

    test "returns error for excessive depth" do
      deep_path = Enum.join(1..10 |> Enum.map(&"Level#{&1}"), " : ")
      assert {:error, {:exceeds_max_depth, _}} = AccountPath.validate(deep_path)
    end
  end

  describe "segments/1" do
    test "splits path into segments" do
      assert AccountPath.segments("Ausgaben : Büro : Material") == ["Ausgaben", "Büro", "Material"]
    end

    test "handles single segment" do
      assert AccountPath.segments("Ausgaben") == ["Ausgaben"]
    end

    test "handles empty path" do
      assert AccountPath.segments("") == []
    end
  end

  describe "parent/1" do
    test "returns parent path" do
      assert AccountPath.parent("Ausgaben : Büro : Material") == "Ausgaben : Büro"
      assert AccountPath.parent("Ausgaben : Büro") == "Ausgaben"
    end

    test "returns nil for root account" do
      assert AccountPath.parent("Ausgaben") == nil
    end

    test "handles empty path" do
      assert AccountPath.parent("") == nil
    end
  end

  describe "ancestors/1" do
    test "returns all ancestors including self" do
      ancestors = AccountPath.ancestors("Ausgaben : Büro : Material")
      assert ancestors == ["Ausgaben", "Ausgaben : Büro", "Ausgaben : Büro : Material"]
    end

    test "handles single segment" do
      assert AccountPath.ancestors("Ausgaben") == ["Ausgaben"]
    end
  end

  describe "ancestors_without_self/1" do
    test "returns ancestors excluding self" do
      ancestors = AccountPath.ancestors_without_self("Ausgaben : Büro : Material")
      assert ancestors == ["Ausgaben", "Ausgaben : Büro"]
    end

    test "returns empty list for root account" do
      assert AccountPath.ancestors_without_self("Ausgaben") == []
    end
  end

  describe "depth/1" do
    test "calculates depth correctly" do
      assert AccountPath.depth("Ausgaben") == 1
      assert AccountPath.depth("Ausgaben : Büro") == 2
      assert AccountPath.depth("Ausgaben : Büro : Material") == 3
    end

    test "handles empty path" do
      assert AccountPath.depth("") == 0
    end
  end

  describe "leaf/1" do
    test "returns last segment" do
      assert AccountPath.leaf("Ausgaben : Büro : Material") == "Material"
      assert AccountPath.leaf("Ausgaben") == "Ausgaben"
    end

    test "handles empty path" do
      assert AccountPath.leaf("") == nil
    end
  end

  describe "join/2" do
    test "joins parent and child" do
      assert AccountPath.join("Ausgaben", "Büro") == "Ausgaben : Büro"
      assert AccountPath.join("Ausgaben : Büro", "Material") == "Ausgaben : Büro : Material"
    end

    test "handles empty parent" do
      assert AccountPath.join("", "Ausgaben") == "Ausgaben"
    end

    test "handles empty child" do
      assert AccountPath.join("Ausgaben", "") == "Ausgaben"
    end
  end

  describe "ancestor?/2" do
    test "detects ancestor relationship" do
      assert AccountPath.ancestor?("Ausgaben", "Ausgaben : Büro : Material")
      assert AccountPath.ancestor?("Ausgaben : Büro", "Ausgaben : Büro : Material")
    end

    test "rejects non-ancestors" do
      refute AccountPath.ancestor?("Einnahmen", "Ausgaben : Büro")
      refute AccountPath.ancestor?("Ausgaben : Büro : Material", "Ausgaben")
    end

    test "rejects self-relationship" do
      refute AccountPath.ancestor?("Ausgaben : Büro", "Ausgaben : Büro")
    end
  end

  describe "descendant?/2" do
    test "detects descendant relationship" do
      assert AccountPath.descendant?("Ausgaben : Büro : Material", "Ausgaben")
      assert AccountPath.descendant?("Ausgaben : Büro : Material", "Ausgaben : Büro")
    end

    test "rejects non-descendants" do
      refute AccountPath.descendant?("Ausgaben : Büro", "Einnahmen")
    end
  end

  describe "sibling?/2" do
    test "detects sibling relationship" do
      assert AccountPath.sibling?("Ausgaben : Büro", "Ausgaben : Personal")
      # Both root accounts
      assert AccountPath.sibling?("Einnahmen", "Ausgaben")
    end

    test "rejects non-siblings" do
      refute AccountPath.sibling?("Ausgaben : Büro", "Ausgaben : Büro : Material")
      refute AccountPath.sibling?("Ausgaben : Büro", "Einnahmen : Arbeit")
    end

    test "rejects self-relationship" do
      refute AccountPath.sibling?("Ausgaben : Büro", "Ausgaben : Büro")
    end
  end

  describe "to_uppercase/1" do
    test "converts to uppercase" do
      result = AccountPath.to_uppercase("einnahmen : arbeit : tideland")
      assert result == "EINNAHMEN : ARBEIT : TIDELAND"
    end
  end

  describe "display/2" do
    test "formats with arrows" do
      result = AccountPath.display("Ausgaben : Büro : Material", :arrow)
      assert result == "Ausgaben → Büro → Material"
    end

    test "formats with depth indication" do
      result = AccountPath.display("Ausgaben : Büro : Material", :leaf_with_depth)
      assert result == "      └── Material"
    end

    test "formats compactly" do
      result = AccountPath.display("Ausgaben : Büro : Material", :compact)
      assert result == "A : B : Material"
    end

    test "handles single segment" do
      result = AccountPath.display("Ausgaben", :compact)
      assert result == "Ausgaben"
    end
  end
end
