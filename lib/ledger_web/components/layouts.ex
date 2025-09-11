defmodule LedgerWeb.Layouts do
  @moduledoc """
  Layouts for the Ledger web application.

  This module defines the root layouts and structure for the application
  according to the WUI design specifications.
  """

  use Phoenix.Component

  @doc """
  Renders the root layout with common HTML structure.
  """
  def root(assigns) do
    assigns = assign_new(assigns, :current_path, fn -> "/" end)
    render_root(assigns)
  end

  @doc """
  Renders the app layout for use within LiveViews.
  """
  def app(assigns) do
    render_app(assigns)
  end

  # Internal rendering functions that use the .heex templates
  defp render_root(assigns), do: Phoenix.Template.render(LedgerWeb.Layouts, "root", "html", assigns)
  defp render_app(assigns), do: Phoenix.Template.render(LedgerWeb.Layouts, "app", "html", assigns)
end
