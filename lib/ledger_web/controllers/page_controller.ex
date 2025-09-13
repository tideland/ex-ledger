defmodule LedgerWeb.PageController do
  use Phoenix.Controller, formats: [:html, :json]

  def home(conn, _params) do
    render(conn, :home, layout: false)
  end
end
