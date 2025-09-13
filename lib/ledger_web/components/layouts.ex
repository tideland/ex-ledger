defmodule LedgerWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.
  """
  use Phoenix.Component

  import Phoenix.Controller, only: [get_csrf_token: 0]

  use Phoenix.VerifiedRoutes,
    endpoint: LedgerWeb.Endpoint,
    router: LedgerWeb.Router,
    statics: ~w(assets fonts images favicon.ico robots.txt)

  embed_templates "layouts/*"
end
