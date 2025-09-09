defmodule TidelandLedger.AccountPath do
  @moduledoc """
  Handles hierarchical account paths with automatic normalization and validation.

  Account paths represent the hierarchical structure of accounts in the ledger system.
  They use a colon separator with spaces for readability, following the pattern
  "Parent : Child : Grandchild". This module provides functions to parse, normalize,
  validate, and manipulate these paths.

  The normalization ensures consistent formatting regardless of how users input the paths,
  making it easier to search and compare accounts.
  """

  @type t :: String.t()

  # The standard separator used in normalized paths
  # This ensures consistent formatting throughout the system
  @separator " : "
  @separator_regex ~r/\s*:\s*/

  # Pattern for valid account segment names
  # Allows letters, numbers, spaces, and common punctuation
  # but excludes colons to avoid confusion with separators
  @valid_segment ~r/^[^:]+$/

  @doc """
  Normalizes an account path to the standard format.

  Takes various input formats and converts them to the canonical form with
  " : " as the separator. Also trims whitespace and removes empty segments.

  ## Examples

      iex> TidelandLedger.AccountPath.normalize("Einnahmen:Arbeit:Tideland")
      "Einnahmen : Arbeit : Tideland"

      iex> TidelandLedger.AccountPath.normalize("Ausgaben  :  Büro:   Material")
      "Ausgaben : Büro : Material"

      iex> TidelandLedger.AccountPath.normalize("Vermögen : Bank : : Girokonto")
      "Vermögen : Bank : Girokonto"
  """
  @spec normalize(String.t()) :: t()
  def normalize(path) when is_binary(path) do
    path
    |> String.split(@separator_regex)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join(@separator)
  end

  @doc """
  Validates an account path.

  Checks that the path follows all rules:
  - Not empty
  - No empty segments
  - Valid characters in each segment
  - Not exceeding maximum depth

  ## Examples

      iex> TidelandLedger.AccountPath.valid?("Einnahmen : Arbeit : Tideland")
      true

      iex> TidelandLedger.AccountPath.valid?("")
      false

      iex> TidelandLedger.AccountPath.valid?("Invalid:Path::DoubleColon")
      false
  """
  @spec valid?(String.t()) :: boolean()
  def valid?(path) when is_binary(path) do
    # First check for empty path
    if String.trim(path) == "" do
      false
    else
      # Check for empty segments (double colons) before normalization
      raw_segments = String.split(path, @separator_regex)

      cond do
        # Check for any empty segments (which indicates double colons or similar issues)
        Enum.any?(raw_segments, &(String.trim(&1) == "")) ->
          false

        # Check depth limit using raw segments
        length(raw_segments) > TidelandLedger.Config.max_account_depth() ->
          false

        # Validate each segment after trimming
        true ->
          raw_segments
          |> Enum.map(&String.trim/1)
          |> Enum.all?(&valid_segment?/1)
      end
    end
  end

  @doc """
  Validates a path and returns a detailed error or :ok.

  This is useful for providing user-friendly error messages when
  account paths are invalid.

  ## Examples

      iex> TidelandLedger.AccountPath.validate("Einnahmen : Arbeit")
      :ok

      iex> TidelandLedger.AccountPath.validate("")
      {:error, :empty_path}

      iex> TidelandLedger.AccountPath.validate("A : B : C : D : E : F : G")
      {:error, {:exceeds_max_depth, 6}}
  """
  @spec validate(String.t()) :: :ok | {:error, atom() | {atom(), any()}}
  def validate(path) when is_binary(path) do
    # First check for empty path
    if String.trim(path) == "" do
      {:error, :empty_path}
    else
      # Check for empty segments (double colons) before normalization
      raw_segments = String.split(path, @separator_regex)

      cond do
        # Check for any empty segments (which indicates double colons or similar issues)
        Enum.any?(raw_segments, &(String.trim(&1) == "")) ->
          {:error, :empty_segment}

        # Check depth limit using raw segments
        length(raw_segments) > TidelandLedger.Config.max_account_depth() ->
          {:error, {:exceeds_max_depth, TidelandLedger.Config.max_account_depth()}}

        # Validate each segment after trimming
        true ->
          trimmed_segments = Enum.map(raw_segments, &String.trim/1)

          case Enum.find(trimmed_segments, &(not valid_segment?(&1))) do
            nil -> :ok
            segment -> {:error, {:invalid_segment, segment}}
          end
      end
    end
  end

  @doc """
  Splits a path into its segments.

  Returns a list of individual account names that make up the path.

  ## Examples

      iex> TidelandLedger.AccountPath.segments("Ausgaben : Büro : Material")
      ["Ausgaben", "Büro", "Material"]

      iex> TidelandLedger.AccountPath.segments("Einnahmen")
      ["Einnahmen"]
  """
  @spec segments(t()) :: [String.t()]
  def segments(path) when is_binary(path) do
    path
    |> normalize()
    |> do_segments()
  end

  defp do_segments(""), do: []

  defp do_segments(normalized_path) do
    String.split(normalized_path, @separator)
  end

  @doc """
  Returns the parent path of the given path.

  Returns nil if the path has no parent (i.e., it's a root account).

  ## Examples

      iex> TidelandLedger.AccountPath.parent("Ausgaben : Büro : Material")
      "Ausgaben : Büro"

      iex> TidelandLedger.AccountPath.parent("Ausgaben : Büro")
      "Ausgaben"

      iex> TidelandLedger.AccountPath.parent("Ausgaben")
      nil
  """
  @spec parent(t()) :: t() | nil
  def parent(path) when is_binary(path) do
    case segments(path) do
      [] ->
        nil

      [_single] ->
        nil

      segments ->
        segments
        |> Enum.drop(-1)
        |> Enum.join(@separator)
    end
  end

  @doc """
  Returns all ancestor paths including the path itself.

  The list is ordered from the root to the given path.

  ## Examples

      iex> TidelandLedger.AccountPath.ancestors("Ausgaben : Büro : Material")
      ["Ausgaben", "Ausgaben : Büro", "Ausgaben : Büro : Material"]

      iex> TidelandLedger.AccountPath.ancestors("Einnahmen")
      ["Einnahmen"]
  """
  @spec ancestors(t()) :: [t()]
  def ancestors(path) when is_binary(path) do
    segments = segments(path)

    1..length(segments)
    |> Enum.map(fn i ->
      segments
      |> Enum.take(i)
      |> Enum.join(@separator)
    end)
  end

  @doc """
  Returns all ancestor paths excluding the path itself.

  The list is ordered from the root to the direct parent.

  ## Examples

      iex> TidelandLedger.AccountPath.ancestors_without_self("Ausgaben : Büro : Material")
      ["Ausgaben", "Ausgaben : Büro"]

      iex> TidelandLedger.AccountPath.ancestors_without_self("Einnahmen")
      []
  """
  @spec ancestors_without_self(t()) :: [t()]
  def ancestors_without_self(path) when is_binary(path) do
    path
    |> ancestors()
    |> Enum.drop(-1)
  end

  @doc """
  Returns the depth (level) of the account path.

  Root accounts have depth 1.

  ## Examples

      iex> TidelandLedger.AccountPath.depth("Ausgaben")
      1

      iex> TidelandLedger.AccountPath.depth("Ausgaben : Büro")
      2

      iex> TidelandLedger.AccountPath.depth("Ausgaben : Büro : Material")
      3
  """
  @spec depth(t()) :: non_neg_integer()
  def depth(path) when is_binary(path) do
    path
    |> segments()
    |> length()
  end

  @doc """
  Returns the leaf (last segment) of the path.

  This is useful for display purposes when you want to show
  just the account name without the full hierarchy.

  ## Examples

      iex> TidelandLedger.AccountPath.leaf("Ausgaben : Büro : Material")
      "Material"

      iex> TidelandLedger.AccountPath.leaf("Einnahmen")
      "Einnahmen"
  """
  @spec leaf(t()) :: String.t() | nil
  def leaf(path) when is_binary(path) do
    path
    |> segments()
    |> List.last()
  end

  @doc """
  Joins a parent path with a child segment.

  This ensures proper normalization when building paths programmatically.

  ## Examples

      iex> TidelandLedger.AccountPath.join("Ausgaben", "Büro")
      "Ausgaben : Büro"

      iex> TidelandLedger.AccountPath.join("Ausgaben : Büro", "Material")
      "Ausgaben : Büro : Material"

      iex> TidelandLedger.AccountPath.join("", "Einnahmen")
      "Einnahmen"
  """
  @spec join(t(), String.t()) :: t()
  def join(parent, child) when is_binary(parent) and is_binary(child) do
    parent = normalize(parent)
    child = String.trim(child)

    cond do
      parent == "" -> child
      child == "" -> parent
      true -> parent <> @separator <> child
    end
  end

  @doc """
  Checks if one path is an ancestor of another.

  A path is considered an ancestor if the descendant path starts with
  the ancestor path followed by a separator.

  ## Examples

      iex> TidelandLedger.AccountPath.ancestor?("Ausgaben", "Ausgaben : Büro : Material")
      true

      iex> TidelandLedger.AccountPath.ancestor?("Ausgaben : Büro", "Ausgaben : Büro")
      false  # Not an ancestor of itself

      iex> TidelandLedger.AccountPath.ancestor?("Einnahmen", "Ausgaben : Büro")
      false
  """
  @spec ancestor?(t(), t()) :: boolean()
  def ancestor?(ancestor_path, descendant_path)
      when is_binary(ancestor_path) and is_binary(descendant_path) do
    ancestor = normalize(ancestor_path)
    descendant = normalize(descendant_path)

    # A path cannot be its own ancestor
    ancestor != descendant && String.starts_with?(descendant, ancestor <> @separator)
  end

  @doc """
  Checks if one path is a descendant of another.

  This is the inverse of ancestor?/2.

  ## Examples

      iex> TidelandLedger.AccountPath.descendant?("Ausgaben : Büro : Material", "Ausgaben")
      true

      iex> TidelandLedger.AccountPath.descendant?("Ausgaben : Büro", "Einnahmen")
      false
  """
  @spec descendant?(t(), t()) :: boolean()
  def descendant?(descendant_path, ancestor_path) do
    ancestor?(ancestor_path, descendant_path)
  end

  @doc """
  Checks if two paths are siblings (share the same parent).

  Root accounts are considered siblings of each other.

  ## Examples

      iex> TidelandLedger.AccountPath.sibling?("Ausgaben : Büro", "Ausgaben : Personal")
      true

      iex> TidelandLedger.AccountPath.sibling?("Einnahmen", "Ausgaben")
      true  # Both are root accounts

      iex> TidelandLedger.AccountPath.sibling?("Ausgaben : Büro", "Ausgaben : Büro : Material")
      false  # Parent-child relationship
  """
  @spec sibling?(t(), t()) :: boolean()
  def sibling?(path1, path2) when is_binary(path1) and is_binary(path2) do
    norm1 = normalize(path1)
    norm2 = normalize(path2)

    # Same path is not a sibling
    norm1 != norm2 && parent(norm1) == parent(norm2)
  end

  @doc """
  Converts a path to uppercase for standardized display.

  This maintains the hierarchical structure while ensuring consistent
  capitalization for cleaner presentation.

  ## Examples

      iex> TidelandLedger.AccountPath.to_uppercase("einnahmen : arbeit : tideland")
      "EINNAHMEN : ARBEIT : TIDELAND"
  """
  @spec to_uppercase(t()) :: t()
  def to_uppercase(path) when is_binary(path) do
    path
    |> segments()
    |> Enum.map(&String.upcase/1)
    |> Enum.join(@separator)
  end

  @doc """
  Creates a human-readable display version of the path.

  This can be used to show paths in a more compact or user-friendly way,
  such as using arrows or just showing the leaf with depth indication.

  ## Examples

      iex> TidelandLedger.AccountPath.display("Ausgaben : Büro : Material")
      "Ausgaben → Büro → Material"

      iex> TidelandLedger.AccountPath.display("Ausgaben : Büro : Material", :leaf_with_depth)
      "    └── Material"

      iex> TidelandLedger.AccountPath.display("Ausgaben : Büro : Material", :compact)
      "A : B : Material"
  """
  @spec display(t(), atom()) :: String.t()
  def display(path, format \\ :arrow) when is_binary(path) do
    case format do
      :arrow ->
        path
        |> segments()
        |> Enum.join(" → ")

      :leaf_with_depth ->
        prefix = String.duplicate("  ", depth(path) - 1)
        "#{prefix}└── #{leaf(path)}"

      :compact ->
        segs = segments(path)

        case segs do
          [] ->
            ""

          [single] ->
            single

          many ->
            init = Enum.drop(many, -1)
            last = List.last(many)

            abbreviated = Enum.map(init, &String.first/1)
            Enum.join(abbreviated ++ [last], " : ")
        end
    end
  end

  # Private helper functions
  # These support the public API with validation and utility functions

  defp valid_segment?(segment) do
    String.match?(segment, @valid_segment) && String.trim(segment) != ""
  end
end
