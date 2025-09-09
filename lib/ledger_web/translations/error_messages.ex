defmodule TidelandLedgerWeb.Translations.ErrorMessages do
  @moduledoc """
  Translates error atoms and tuples from the business logic layer into
  user-friendly messages in the appropriate language.

  This module serves as the single source of truth for all error message
  translations in the UI layer. Business logic modules should only return
  error atoms or tuples, never translated strings.
  """

  # Account-related error messages
  # These handle validation errors from the Accounts context

  def translate_error(error, locale \\ :de)

  def translate_error(:empty_path, _locale) do
    "Kontopfad darf nicht leer sein"
  end

  def translate_error({:exceeds_max_depth, max}, _locale) do
    "Kontopfad überschreitet die maximale Tiefe von #{max} Ebenen"
  end

  def translate_error({:invalid_segment, segment}, _locale) do
    "Kontopfad enthält ungültiges Segment: #{segment}"
  end

  def translate_error(:has_active_children, _locale) do
    "Konto kann nicht deaktiviert werden, da aktive Unterkonten existieren"
  end

  def translate_error({:has_recent_transactions, days}, _locale) do
    "Konto kann nicht deaktiviert werden, da Transaktionen in den letzten #{days} Tagen existieren"
  end

  def translate_error(:account_not_found, _locale) do
    "Konto nicht gefunden"
  end

  def translate_error(:parent_account_not_found, _locale) do
    "Übergeordnetes Konto nicht gefunden"
  end

  def translate_error(:account_inactive, _locale) do
    "Konto ist inaktiv und kann nicht verwendet werden"
  end

  def translate_error(:duplicate_account_path, _locale) do
    "Ein Konto mit diesem Pfad existiert bereits"
  end

  # Transaction-related error messages
  # These handle validation errors from the Transactions context

  def translate_error(:transaction_not_balanced, _locale) do
    "Buchung ist nicht ausgeglichen"
  end

  def translate_error(:insufficient_positions, _locale) do
    "Buchung muss mindestens zwei Positionen enthalten"
  end

  def translate_error({:exceeds_max_positions, max}, _locale) do
    "Buchung darf maximal #{max} Positionen enthalten"
  end

  def translate_error(:invalid_transaction_date, _locale) do
    "Ungültiges Buchungsdatum"
  end

  def translate_error({:exceeds_backdate_limit, days}, _locale) do
    "Buchung darf maximal #{days} Tage in der Vergangenheit liegen"
  end

  def translate_error(:period_closed, _locale) do
    "Buchungsperiode ist geschlossen"
  end

  def translate_error(:transaction_already_posted, _locale) do
    "Buchung wurde bereits verbucht"
  end

  def translate_error(:transaction_already_voided, _locale) do
    "Buchung wurde bereits storniert"
  end

  def translate_error(:void_reason_required, _locale) do
    "Stornierungsgrund ist erforderlich"
  end

  # Amount-related error messages
  # These handle validation errors from amount calculations

  def translate_error(:invalid_amount_format, _locale) do
    "Ungültiges Betragsformat"
  end

  def translate_error(:amount_too_large, _locale) do
    "Betrag ist zu groß"
  end

  def translate_error(:currency_mismatch, _locale) do
    "Währungen stimmen nicht überein"
  end

  def translate_error(:division_by_zero, _locale) do
    "Division durch Null nicht erlaubt"
  end

  # Template-related error messages
  # These handle validation errors from the Templates context

  def translate_error(:template_not_found, _locale) do
    "Vorlage nicht gefunden"
  end

  def translate_error(:template_version_not_found, _locale) do
    "Vorlagenversion nicht gefunden"
  end

  def translate_error(:invalid_template_positions, _locale) do
    "Ungültige Vorlagenpositionen"
  end

  def translate_error(:template_accounts_not_found, _locale) do
    "Ein oder mehrere Konten in der Vorlage existieren nicht"
  end

  # User and authentication error messages
  # These handle validation errors from the Users context

  def translate_error(:invalid_credentials, _locale) do
    "Ungültige Anmeldedaten"
  end

  def translate_error(:unauthorized, _locale) do
    "Keine Berechtigung für diese Aktion"
  end

  def translate_error(:session_expired, _locale) do
    "Sitzung abgelaufen, bitte erneut anmelden"
  end

  def translate_error(:user_inactive, _locale) do
    "Benutzerkonto ist inaktiv"
  end

  def translate_error(:insufficient_permissions, _locale) do
    "Unzureichende Berechtigungen"
  end

  # Import/Export error messages
  # These handle validation errors from import/export operations

  def translate_error(:invalid_file_format, _locale) do
    "Ungültiges Dateiformat"
  end

  def translate_error({:file_too_large, max_mb}, _locale) do
    "Datei ist zu groß (maximal #{max_mb} MB)"
  end

  def translate_error(:import_parse_error, _locale) do
    "Fehler beim Parsen der Importdatei"
  end

  def translate_error({:invalid_row, row_number}, _locale) do
    "Ungültige Daten in Zeile #{row_number}"
  end

  def translate_error(:export_failed, _locale) do
    "Export fehlgeschlagen"
  end

  # Generic validation messages
  # These are used by Ecto changesets

  def translate_error(:required, _locale) do
    "Pflichtfeld"
  end

  def translate_error({:min_length, min}, _locale) do
    "Muss mindestens #{min} Zeichen lang sein"
  end

  def translate_error({:max_length, max}, _locale) do
    "Darf maximal #{max} Zeichen lang sein"
  end

  def translate_error(:invalid_format, _locale) do
    "Ungültiges Format"
  end

  def translate_error(:not_found, _locale) do
    "Nicht gefunden"
  end

  # Fallback for unknown errors
  # This ensures we always return something readable

  def translate_error(error, _locale) when is_atom(error) do
    # Convert atom to readable string
    error
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  def translate_error({error, _details}, locale) when is_atom(error) do
    # Try translating just the error atom
    translate_error(error, locale)
  end

  def translate_error(_error, _locale) do
    "Ein unbekannter Fehler ist aufgetreten"
  end

  @doc """
  Translates a list of errors, typically from a changeset.

  Returns a list of translated error messages.
  """
  def translate_errors(errors, locale \\ :de) when is_list(errors) do
    Enum.map(errors, &translate_error(&1, locale))
  end

  @doc """
  Translates errors from an Ecto changeset.

  Returns a map with field names as keys and lists of translated
  error messages as values.
  """
  def translate_changeset_errors(changeset, locale \\ :de) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} ->
      # Handle both simple messages and those with interpolation
      case msg do
        # If it's already a string (shouldn't happen with our approach)
        str when is_binary(str) ->
          str

        # If it's an atom
        atom when is_atom(atom) ->
          translate_error(atom, locale)

        # If it's a tuple (our error format)
        tuple when is_tuple(tuple) ->
          translate_error(tuple, locale)

        # Fallback
        _ ->
          translate_error(:unknown_error, locale)
      end
    end)
  end

  @doc """
  Helper function for Phoenix forms to translate errors inline.

  Usage in templates:
    <%= error_tag(f, :path, &ErrorMessages.translate_error/1) %>
  """
  def for_field(form, field, locale \\ :de) do
    Keyword.get_values(form.errors, field)
    |> Enum.map(&translate_error(&1, locale))
  end
end
