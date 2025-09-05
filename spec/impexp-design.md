# Tideland Ledger - Import/Export Design

## 1. Overview

This document specifies the import and export functionality for the Tideland Ledger system. The design focuses on CSV and JSON formats with clear rules for data validation, idempotency, and error handling.

## 2. Export Functionality

### 2.1 Supported Export Formats

- **CSV**: For spreadsheet compatibility
- **JSON**: For programmatic access and backup

### 2.2 Export Types

#### 2.2.1 Account Export

**CSV Format**:

```csv
"Kontonummer";"Kontoname";"Übergeordnetes Konto";"Beschreibung";"Aktiv";"Saldo"
"Vermögen : Bank : Girokonto";"Girokonto";"Vermögen : Bank";"Hauptbankkonto";"Ja";"12500,00"
"Vermögen : Bank : Sparkonto";"Sparkonto";"Vermögen : Bank";"Rücklagen";"Ja";"25000,00"
```

**JSON Format**:

```json
{
  "export_type": "accounts",
  "export_date": "2024-02-15T10:30:00Z",
  "version": "1.0",
  "accounts": [
    {
      "path": "Vermögen : Bank : Girokonto",
      "name": "Girokonto",
      "parent": "Vermögen : Bank",
      "description": "Hauptbankkonto",
      "active": true,
      "balance": "12500.00"
    }
  ]
}
```

#### 2.2.2 Entry Export

**CSV Format**:

```csv
"Datum";"Belegnummer";"Beschreibung";"Konto";"Betrag";"Steuerelevant"
"2024-02-01";"2024-001";"Miete Februar";"Ausgaben : Wohnung : Miete";"1200,00";"Nein"
"2024-02-01";"2024-001";"Miete Februar";"Vermögen : Bank : Girokonto";"-1200,00";"Nein"
```

**JSON Format**:

```json
{
  "export_type": "entries",
  "export_date": "2024-02-15T10:30:00Z",
  "version": "1.0",
  "date_range": {
    "from": "2024-02-01",
    "to": "2024-02-28"
  },
  "entries": [
    {
      "date": "2024-02-01",
      "reference": "2024-001",
      "description": "Miete Februar",
      "positions": [
        {
          "account": "Ausgaben : Wohnung : Miete",
          "amount": "1200.00",
          "tax_relevant": false
        },
        {
          "account": "Vermögen : Bank : Girokonto",
          "amount": "-1200.00",
          "tax_relevant": false
        }
      ]
    }
  ]
}
```

### 2.3 Export Configuration

```elixir
defmodule Ledger.Export.Config do
  defstruct [
    :format,           # :csv or :json
    :type,            # :accounts, :entries, :trial_balance
    :date_from,       # Date or nil
    :date_to,         # Date or nil
    :include_inactive, # boolean
    :decimal_separator, # "," for German, "." for international
    :field_separator,  # ";" for German CSV
    :encoding         # :utf8
  ]
end
```

## 3. Import Functionality

### 3.1 Import Process

1. **Upload**: File selection and validation
2. **Preview**: Show first 10 rows with mapping
3. **Mapping**: Column to field assignment
4. **Validation**: Check all data before import
5. **Import**: Process with transaction safety
6. **Report**: Summary of imported records

### 3.2 CSV Import Rules

#### 3.2.1 Account Import

**Required Columns**:

- Kontonummer (Account Path)
- Kontoname (Account Name)

**Optional Columns**:

- Übergeordnetes Konto (Parent Account)
- Beschreibung (Description)
- Aktiv (Active status)

**Validation Rules**:

- Account paths must use " : " separator
- Parent accounts must exist or be created first
- Duplicate account paths are skipped (idempotency)

#### 3.2.2 Entry Import

**Required Columns**:

- Datum (Date)
- Beschreibung (Description)
- Konto (Account)
- Betrag (Amount)

**Optional Columns**:

- Belegnummer (Reference Number)
- Steuerelevant (Tax Relevant)

**Validation Rules**:

- Dates must be valid (DD.MM.YYYY or YYYY-MM-DD)
- Amounts use German format (1.234,56) or international (1234.56)
- Accounts must exist before import
- Each entry must balance (sum = 0)
- Minimum two positions per entry

### 3.3 Idempotency Rules

```elixir
defmodule Ledger.Import.Idempotency do
  # Account idempotency: based on account path
  def account_key(row) do
    normalize_account_path(row["Kontonummer"])
  end

  # Entry idempotency: based on date + reference + amount hash
  def entry_key(positions) do
    date = positions |> List.first() |> Map.get("date")
    reference = positions |> List.first() |> Map.get("reference", "")
    amount_hash = positions
      |> Enum.map(&Map.get(&1, "amount"))
      |> Enum.sort()
      |> :erlang.phash2()

    "#{date}:#{reference}:#{amount_hash}"
  end
end
```

### 3.4 Error Handling

```elixir
defmodule Ledger.Import.Result do
  defstruct [
    :total_rows,
    :successful_imports,
    :skipped_duplicates,
    :errors,
    :warnings
  ]

  # Error types
  @error_types %{
    invalid_format: "Ungültiges Format",
    missing_required: "Pflichtfeld fehlt",
    invalid_date: "Ungültiges Datum",
    invalid_amount: "Ungültiger Betrag",
    account_not_found: "Konto nicht gefunden",
    unbalanced_entry: "Buchung nicht ausgeglichen"
  }
end
```

## 4. Import Mapping

### 4.1 Column Mapping Interface

```elixir
defmodule Ledger.Import.Mapping do
  defstruct [
    :source_columns,     # ["Col1", "Col2", ...]
    :target_fields,      # [:date, :description, :account, :amount]
    :mappings,          # %{source_column => target_field}
    :transformations,    # %{target_field => transform_fn}
    :preview_rows       # First 10 rows for preview
  ]

  # Common transformations
  def transform_date(value) do
    cond do
      # German format: DD.MM.YYYY
      String.match?(value, ~r/^\d{2}\.\d{2}\.\d{4}$/) ->
        [day, month, year] = String.split(value, ".")
        Date.from_iso8601!("#{year}-#{month}-#{day}")

      # ISO format: YYYY-MM-DD
      String.match?(value, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        Date.from_iso8601!(value)

      true ->
        {:error, :invalid_date_format}
    end
  end

  def transform_amount(value) do
    value
    |> String.replace(".", "")  # Remove thousand separators
    |> String.replace(",", ".")  # Convert decimal separator
    |> Decimal.parse()
    |> case do
      {:ok, decimal} -> {:ok, decimal}
      :error -> {:error, :invalid_amount}
    end
  end
end
```

### 4.2 Import Templates

```elixir
# Predefined import templates for common formats
defmodule Ledger.Import.Templates do
  def sparkasse_csv do
    %{
      name: "Sparkasse CSV",
      mappings: %{
        "Buchungstag" => :date,
        "Verwendungszweck" => :description,
        "Betrag" => :amount,
        "Empfänger/Zahlungspflichtiger" => :reference
      },
      default_account: "Vermögen : Bank : Girokonto"
    }
  end

  def dkb_csv do
    %{
      name: "DKB CSV",
      mappings: %{
        "Valutadatum" => :date,
        "Beschreibung" => :description,
        "Betrag (EUR)" => :amount,
        "Auftraggeber / Empfänger" => :reference
      },
      default_account: "Vermögen : Bank : Girokonto"
    }
  end
end
```

## 5. Batch Processing

### 5.1 Large File Handling

```elixir
defmodule Ledger.Import.Batch do
  @batch_size 100

  def process_file(file_path, config) do
    file_path
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Stream.chunk_every(@batch_size)
    |> Stream.with_index()
    |> Enum.reduce(%Result{}, fn {batch, index}, acc ->
      process_batch(batch, index, config, acc)
    end)
  end

  defp process_batch(rows, batch_index, config, result) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:validate, fn _repo, _changes ->
      validate_batch(rows, config)
    end)
    |> Ecto.Multi.run(:import, fn repo, %{validate: validated_rows} ->
      import_rows(repo, validated_rows, config)
    end)
    |> Repo.transaction()
    |> handle_batch_result(result)
  end
end
```

## 6. Export Scheduling

### 6.1 Automated Exports

```elixir
defmodule Ledger.Export.Scheduler do
  use GenServer

  # Daily backup export
  def schedule_daily_backup do
    config = %Config{
      format: :json,
      type: :full_backup,
      include_inactive: true
    }

    schedule_export(config, "0 2 * * *")  # 2 AM daily
  end

  # Monthly reports
  def schedule_monthly_reports do
    config = %Config{
      format: :csv,
      type: :trial_balance,
      date_from: :beginning_of_month,
      date_to: :end_of_month
    }

    schedule_export(config, "0 6 1 * *")  # 6 AM first of month
  end
end
```

## 7. Security Considerations

### 7.1 Import Security

- File size limits (max 10MB)
- Virus scanning before processing
- Validation of all data before database writes
- Entry rollback on any error
- Audit logging of all imports

### 7.2 Export Security

- Role-based access control
- Audit logging of all exports
- Optional data anonymization
- Encrypted file storage for scheduled exports

## 8. Performance Optimization

### 8.1 Import Performance

- Stream processing for large files
- Batch inserts with configurable batch size
- Index temporary disable during large imports
- Progress reporting via Phoenix PubSub

### 8.2 Export Performance

- Streaming JSON/CSV generation
- Pagination for large datasets
- Background job processing for large exports
- Caching of frequently exported reports

## 9. User Interface

### 9.1 Import Wizard

```
┌─────────────────────────────────────────────────────────────┐
│                    Daten importieren                        │
├─────────────────────────────────────────────────────────────┤
│ 1. Datei auswählen                                         │
│    [Datei auswählen] transactions.csv (2.3 MB)            │
│                                                             │
│ 2. Format erkennen                                         │
│    ○ Automatisch erkennen                                  │
│    ○ Sparkasse CSV                                         │
│    ○ DKB CSV                                               │
│    ● Benutzerdefiniert                                     │
│                                                             │
│ 3. Spalten zuordnen                                        │
│    Quelldatei              →  Zielfeld                     │
│    [Buchungstag      ▼]    →  [Datum           ▼]         │
│    [Verwendungszweck ▼]    →  [Beschreibung    ▼]         │
│    [Betrag          ▼]    →  [Betrag          ▼]         │
│                                                             │
│ 4. Vorschau (erste 5 Zeilen)                              │
│    ┌──────────┬─────────────────┬──────────┐              │
│    │ Datum    │ Beschreibung    │ Betrag   │              │
│    ├──────────┼─────────────────┼──────────┤              │
│    │ 01.02.24 │ Miete Februar   │ 1.200,00 │              │
│    │ 05.02.24 │ Einkauf REWE    │   87,43  │              │
│    └──────────┴─────────────────┴──────────┘              │
│                                                             │
│ [Abbrechen]                           [Import starten]      │
└─────────────────────────────────────────────────────────────┘
```

### 9.2 Export Dialog

```
┌─────────────────────────────────────────────────────────────┐
│                    Daten exportieren                        │
├─────────────────────────────────────────────────────────────┤
│ Was möchten Sie exportieren?                               │
│ ○ Kontenplan                                               │
│ ● Buchungen                                                │
│ ○ Probebilanz                                              │
│                                                             │
│ Zeitraum:                                                  │
│ Von: [01.02.2024] bis [29.02.2024]                        │
│                                                             │
│ Format:                                                    │
│ ○ CSV (Excel-kompatibel)                                  │
│ ● JSON (Backup)                                            │
│                                                             │
│ Optionen:                                                  │
│ □ Inaktive Konten einschließen                            │
│ ☑ Steuerelevante Markierung                               │
│                                                             │
│ [Abbrechen]                              [Exportieren]      │
└─────────────────────────────────────────────────────────────┘
```

## 10. Testing Considerations

### 10.1 Import Testing

- Golden files for each supported format
- Edge cases: empty files, malformed data, huge files
- Idempotency tests: importing same file twice
- Character encoding tests: UTF-8, ISO-8859-1
- Number format tests: German vs. international

### 10.2 Export Testing

- Round-trip tests: export → import → compare
- Format validation against specifications
- Performance tests with large datasets
- Concurrent export handling
