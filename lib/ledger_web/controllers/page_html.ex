defmodule LedgerWeb.PageHTML do
  @moduledoc """
  HTML rendering for the PageController.

  This module contains the rendering functions for static pages in the Ledger application.
  """

  use LedgerWeb, :html

  # Import helpers for formatting data
  import LedgerWeb.LiveHelpers, only: [format_amount: 1, format_date: 1]

  # Render templates from the page_html directory
  # Phoenix will look for templates in lib/ledger_web/controllers/page_html/
  embed_templates "page_html/*"
end
