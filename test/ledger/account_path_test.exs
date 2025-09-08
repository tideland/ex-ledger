defmodule TidelandLedger.AccountPathTest do
  use ExUnit.Case, async: true
  alias TidelandLedger.AccountPath

  describe "normalization" do
    test "normalize/1 handles standard format" do
      assert AccountPath.normalize("Einnahmen : Arbeit : Tideland") ==
               "Einnahmen : Arbeit : Tideland"
    end

    test "normalize/1 fixes spacing around colons" do
      assert AccountPath.normalize("Einnahmen:Arbeit:Tideland") == "Einnahmen : Arbeit : Tideland"

      assert AccountPath.normalize("Ausgaben  :  Büro:   Material") ==
               "Ausgaben : Büro : Material"

      assert AccountPath.normalize("Ausgaben: Büro :Material") == "Ausgaben : Büro : Material"
    end

    test "normalize/1 removes empty segments" do
      assert AccountPath.normalize("Vermögen : : Bank : : Girokonto") ==
               "Vermögen : Bank : Girokonto"

      assert AccountPath.normalize(" : Ausgaben : Büro : ") == "Ausgaben : Büro"
    end

    test "normalize/1 trims whitespace" do
      assert AccountPath.normalize("  Einnahmen : Arbeit  ") == "Einnahmen : Arbeit"
      assert AccountPath.normalize(" Ausgaben   :   Büro ") == "Ausgaben : Büro"
    end

    test "normalize/1 handles single segment" do
      assert AccountPath.normalize("Einnahmen") == "Einnahmen"
      assert AccountPath.normalize("  Ausgaben  ") == "Ausgaben"
    end

    test "normalize/1 handles empty string" do
      assert AccountPath.normalize("") == ""
      assert AccountPath.normalize("   ") == ""
      assert AccountPath.normalize(" : : ") == ""
    end
  end

  describe "validation" do
    test "valid?/1 accepts valid paths" do
      assert AccountPath.valid?("Einnahmen")
      assert AccountPath.valid?("Einnahmen : Arbeit")
      assert AccountPath.valid?("Einnahmen : Arbeit : Tideland")
      assert AccountPath.valid?("Ausgaben : Büro : Material : Schreibwaren")
    end

    test "valid?/1 rejects empty paths" do
      refute AccountPath.valid?("")
      refute AccountPath.valid?("   ")
      refute AccountPath.valid?(" : : ")
    end

    test "valid?/1 accepts paths up to max depth" do
      # Max depth is 6
      assert AccountPath.valid?("A : B : C : D : E : F")
      refute AccountPath.valid?("A : B : C : D : E : F : G")
    end

    test "valid?/1 accepts various characters in segments" do
      assert AccountPath.valid?("Ausgaben 2024")
      assert AccountPath.valid?("Büro & Material")
      assert AccountPath.valid?("Konto-123")
      assert AccountPath.valid?("10% Rabatt")
    end

    test "validate/1 returns detailed errors" do
      assert AccountPath.validate("Einnahmen : Arbeit") == :ok

      assert AccountPath.validate("") == {:error, :empty_path}
      assert AccountPath.validate("   ") == {:error, :empty_path}

      assert AccountPath.validate("A : B : C : D : E : F : G") ==
               {:error, {:exceeds_max_depth, 6}}
    end
  end

  describe "segments" do
    test "segments/1 splits path correctly" do
      assert AccountPath.segments("Ausgaben : Büro : Material") == [
               "Ausgaben",
               "Büro",
               "Material"
             ]

      assert AccountPath.segments("Einnahmen") == ["Einnahmen"]
      assert AccountPath.segments("") == []
    end

    test "segments/1 normalizes before splitting" do
      assert AccountPath.segments("Ausgaben:Büro:Material") == ["Ausgaben", "Büro", "Material"]
      assert AccountPath.segments("  Ausgaben : : Büro  ") == ["Ausgaben", "Büro"]
    end
  end

  describe "parent" do
    test "parent/1 returns parent path" do
      assert AccountPath.parent("Ausgaben : Büro : Material") == "Ausgaben : Büro"
      assert AccountPath.parent("Ausgaben : Büro") == "Ausgaben"
      assert AccountPath.parent("Ausgaben") == nil
    end

    test "parent/1 handles normalized input" do
      assert AccountPath.parent("Ausgaben:Büro:Material") == "Ausgaben : Büro"
      assert AccountPath.parent("  Ausgaben : Büro  ") == "Ausgaben"
    end

    test "parent/1 returns nil for empty path" do
      assert AccountPath.parent("") == nil
    end
  end

  describe "ancestors" do
    test "ancestors/1 returns all ancestor paths including self" do
      assert AccountPath.ancestors("Ausgaben : Büro : Material") ==
               ["Ausgaben", "Ausgaben : Büro", "Ausgaben : Büro : Material"]

      assert AccountPath.ancestors("Einnahmen") == ["Einnahmen"]
      assert AccountPath.ancestors("") == []
    end

    test "ancestors_without_self/1 excludes the path itself" do
      assert AccountPath.ancestors_without_self("Ausgaben : Büro : Material") ==
               ["Ausgaben", "Ausgaben : Büro"]

      assert AccountPath.ancestors_without_self("Ausgaben : Büro") == ["Ausgaben"]
      assert AccountPath.ancestors_without_self("Einnahmen") == []
    end
  end

  describe "depth" do
    test "depth/1 returns correct level" do
      assert AccountPath.depth("Ausgaben") == 1
      assert AccountPath.depth("Ausgaben : Büro") == 2
      assert AccountPath.depth("Ausgaben : Büro : Material") == 3
      assert AccountPath.depth("A : B : C : D : E : F") == 6
    end

    test "depth/1 returns 0 for empty path" do
      assert AccountPath.depth("") == 0
    end
  end

  describe "leaf" do
    test "leaf/1 returns last segment" do
      assert AccountPath.leaf("Ausgaben : Büro : Material") == "Material"
      assert AccountPath.leaf("Ausgaben : Büro") == "Büro"
      assert AccountPath.leaf("Einnahmen") == "Einnahmen"
    end

    test "leaf/1 returns nil for empty path" do
      assert AccountPath.leaf("") == nil
    end
  end

  describe "join" do
    test "join/2 combines paths correctly" do
      assert AccountPath.join("Ausgaben", "Büro") == "Ausgaben : Büro"
      assert AccountPath.join("Ausgaben : Büro", "Material") == "Ausgaben : Büro : Material"
    end

    test "join/2 handles empty parent" do
      assert AccountPath.join("", "Einnahmen") == "Einnahmen"
    end

    test "join/2 handles empty child" do
      assert AccountPath.join("Ausgaben", "") == "Ausgaben"
    end

    test "join/2 normalizes inputs" do
      assert AccountPath.join("Ausgaben:Büro", "Material") == "Ausgaben : Büro : Material"
      assert AccountPath.join("  Ausgaben  ", "  Büro  ") == "Ausgaben : Büro"
    end
  end

  describe "ancestor/descendant relationships" do
    test "ancestor?/2 identifies ancestors correctly" do
      assert AccountPath.ancestor?("Ausgaben", "Ausgaben : Büro : Material")
      assert AccountPath.ancestor?("Ausgaben : Büro", "Ausgaben : Büro : Material")

      refute AccountPath.ancestor?("Ausgaben : Büro", "Ausgaben : Büro")
      refute AccountPath.ancestor?("Einnahmen", "Ausgaben : Büro")
      refute AccountPath.ancestor?("Ausgaben : Büro : Material", "Ausgaben : Büro")
    end

    test "descendant?/2 is inverse of ancestor?" do
      assert AccountPath.descendant?("Ausgaben : Büro : Material", "Ausgaben")
      assert AccountPath.descendant?("Ausgaben : Büro : Material", "Ausgaben : Büro")

      refute AccountPath.descendant?("Ausgaben", "Ausgaben : Büro")
      refute AccountPath.descendant?("Ausgaben : Büro", "Ausgaben : Büro")
    end
  end

  describe "sibling relationships" do
    test "sibling?/2 identifies siblings" do
      assert AccountPath.sibling?("Ausgaben : Büro", "Ausgaben : Personal")
      assert AccountPath.sibling?("Einnahmen", "Ausgaben")

      refute AccountPath.sibling?("Ausgaben : Büro", "Ausgaben : Büro")
      refute AccountPath.sibling?("Ausgaben : Büro", "Ausgaben : Büro : Material")
      refute AccountPath.sibling?("Ausgaben", "Ausgaben : Büro")
    end

    test "sibling?/2 handles normalization" do
      assert AccountPath.sibling?("Ausgaben:Büro", "Ausgaben : Personal")
    end
  end

  describe "case conversion" do
    test "to_uppercase/1 converts entire path" do
      assert AccountPath.to_uppercase("einnahmen : arbeit : tideland") ==
               "EINNAHMEN : ARBEIT : TIDELAND"

      assert AccountPath.to_uppercase("Ausgaben : Büro") == "AUSGABEN : BÜRO"
    end

    test "to_uppercase/1 maintains structure" do
      assert AccountPath.to_uppercase("einnahmen:arbeit:tideland") ==
               "EINNAHMEN : ARBEIT : TIDELAND"
    end
  end

  describe "display formatting" do
    test "display/2 with arrow format" do
      assert AccountPath.display("Ausgaben : Büro : Material") ==
               "Ausgaben → Büro → Material"

      assert AccountPath.display("Einnahmen", :arrow) == "Einnahmen"
    end

    test "display/2 with leaf_with_depth format" do
      assert AccountPath.display("Material", :leaf_with_depth) == "└── Material"
      assert AccountPath.display("Büro : Material", :leaf_with_depth) == "  └── Material"

      assert AccountPath.display("Ausgaben : Büro : Material", :leaf_with_depth) ==
               "    └── Material"
    end

    test "display/2 with compact format" do
      assert AccountPath.display("Ausgaben : Büro : Material", :compact) ==
               "A : B : Material"

      assert AccountPath.display("Ausgaben : Büro", :compact) == "A : Büro"
      assert AccountPath.display("Ausgaben", :compact) == "Ausgaben"
    end

    test "display/2 handles empty path" do
      assert AccountPath.display("", :arrow) == ""
      assert AccountPath.display("", :compact) == ""
    end
  end

  describe "edge cases" do
    test "handles German umlauts and special characters" do
      path = "Ausgaben : Büro : Möbel & Ausstattung"
      assert AccountPath.normalize(path) == path
      assert AccountPath.valid?(path)
      assert AccountPath.leaf(path) == "Möbel & Ausstattung"
    end

    test "handles numeric segments" do
      assert AccountPath.valid?("2024 : Januar : Ausgaben")
      assert AccountPath.normalize("2024:01:Ausgaben") == "2024 : 01 : Ausgaben"
    end

    test "handles very long segment names" do
      long_segment = "Sehr lange Kontobezeichnung mit vielen Wörtern"
      path = "Ausgaben : #{long_segment}"
      assert AccountPath.valid?(path)
      assert AccountPath.leaf(path) == long_segment
    end

    test "consistency across operations" do
      original = "Ausgaben:Büro:  Material"
      normalized = AccountPath.normalize(original)

      # All operations should produce consistent normalized output
      assert AccountPath.join(AccountPath.parent(normalized), AccountPath.leaf(normalized)) ==
               normalized

      assert AccountPath.ancestors(normalized) |> List.last() == normalized
    end
  end
end
