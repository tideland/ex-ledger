defmodule LedgerWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.

  This module provides helper functions for Phoenix views and templates
  to display translated error messages from changesets and other sources.
  It acts as a bridge between the business logic's error atoms and the
  UI's translated messages.
  """

  use Phoenix.HTML

  alias LedgerWeb.Translations.ErrorMessages

  @doc """
  Generates tag for inlined form input errors.

  ## Examples

      <%= error_tag(f, :username) %>
      <%= error_tag(f, :username, class: "error-text") %>
  """
  def error_tag(form, field, opts \\ []) do
    errors = Keyword.get_values(form.errors, field)

    if errors != [] do
      content_tag(:div, class: error_class(opts)) do
        Enum.map(errors, fn error ->
          content_tag(:span, translate_error(error))
        end)
      end
    end
  end

  @doc """
  Returns a list of translated error messages for a field.

  ## Examples

      <%= for msg <- error_messages(f, :path) do %>
        <p class="error"><%= msg %></p>
      <% end %>
  """
  def error_messages(form, field) do
    Keyword.get_values(form.errors, field)
    |> Enum.map(&translate_error/1)
  end

  @doc """
  Checks if a field has any errors.

  ## Examples

      <div class="<%= if has_error?(f, :path), do: "field-error" %>">
        ...
      </div>
  """
  def has_error?(form, field) do
    Keyword.has_key?(form.errors, field)
  end

  @doc """
  Translates an error message.

  This function handles various error formats:
  - Simple atoms: :required
  - Tuples: {:too_long, 255}
  - Ecto validation tuples: {"should be at least %{count}", [count: 5]}
  """
  def translate_error(error) when is_atom(error) do
    ErrorMessages.translate_error(error)
  end

  def translate_error({error, opts}) when is_atom(error) do
    ErrorMessages.translate_error({error, opts})
  end

  # Handle Ecto's default validation messages
  # These come as {"message", opts} tuples
  def translate_error({msg, opts}) when is_binary(msg) do
    # Map common Ecto messages to our atoms
    atom = ecto_message_to_atom(msg)

    if atom do
      ErrorMessages.translate_error(build_error_tuple(atom, opts))
    else
      # Fallback to the original message if we don't recognize it
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end
  end

  @doc """
  Returns all errors from a changeset as a flat list of translated messages.

  ## Examples

      case Accounts.create_user(params) do
        {:ok, user} -> ...
        {:error, changeset} ->
          messages = all_errors(changeset)
          render(conn, "new.html", errors: messages)
      end
  """
  def all_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    |> Enum.flat_map(fn {_field, messages} -> messages end)
  end

  @doc """
  Returns errors from a changeset as a field-keyed map of translated messages.

  ## Examples

      errors = field_errors(changeset)
      # => %{username: ["Pflichtfeld"], email: ["Ungültiges Format"]}
  """
  def field_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
  end

  @doc """
  Formats errors for JSON responses.

  Returns a structure suitable for API error responses:
  %{errors: %{field_name: ["error message", ...]}}
  """
  def format_errors_for_json(changeset) do
    errors = Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    %{errors: errors}
  end

  # Private helper functions

  defp error_class(opts) do
    Keyword.get(opts, :class, "error-message")
  end

  # Map Ecto's default validation messages to our error atoms
  defp ecto_message_to_atom("can't be blank"), do: :required
  defp ecto_message_to_atom("has invalid format"), do: :invalid_format
  defp ecto_message_to_atom("has already been taken"), do: :already_taken
  defp ecto_message_to_atom("is invalid"), do: :invalid
  defp ecto_message_to_atom("must be accepted"), do: :must_be_accepted
  defp ecto_message_to_atom("should be at least %{count} character(s)"), do: :min_length
  defp ecto_message_to_atom("should be at most %{count} character(s)"), do: :max_length
  defp ecto_message_to_atom("should be %{count} character(s)"), do: :exact_length
  defp ecto_message_to_atom("should be at least %{number}"), do: :min_value
  defp ecto_message_to_atom("should be at most %{number}"), do: :max_value
  defp ecto_message_to_atom("must be less than %{number}"), do: :less_than
  defp ecto_message_to_atom("must be greater than %{number}"), do: :greater_than
  defp ecto_message_to_atom("must be equal to %{number}"), do: :equal_to
  defp ecto_message_to_atom(_), do: nil

  # Build error tuple from atom and opts
  defp build_error_tuple(atom, opts) do
    case {atom, opts} do
      {:min_length, [count: count, validation: :length]} -> {:min_length, count}
      {:max_length, [count: count, validation: :length]} -> {:max_length, count}
      {:exact_length, [count: count, validation: :length]} -> {:exact_length, count}
      {:min_value, [number: num]} -> {:min_value, num}
      {:max_value, [number: num]} -> {:max_value, num}
      {:less_than, [number: num]} -> {:less_than, num}
      {:greater_than, [number: num]} -> {:greater_than, num}
      {:equal_to, [number: num]} -> {:equal_to, num}
      {atom, _} -> atom
    end
  end
end
