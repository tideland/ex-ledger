defmodule LedgerWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.
  """
  use Phoenix.Component

  embed_templates "page_html/*"
end
