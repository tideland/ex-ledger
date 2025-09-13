defmodule LedgerWeb.PageController do
  use Phoenix.Controller,
    formats: [:html, :json],
    layouts: [html: LedgerWeb.Layouts]

  def home(conn, _params) do
    conn
    |> assign(:active_menu, :dashboard)
    |> assign(:page_title, "Übersicht")
    |> render(:home, layout: {LedgerWeb.Layouts, :app})
  end
end
