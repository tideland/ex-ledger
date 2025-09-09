defmodule TidelandLedger.MixProject do
  use Mix.Project

  def project do
    [
      app: :tideland_ledger,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),

      # Hex package information
      name: "Tideland Ledger",
      description: "A web-based simplified ledger-style bookkeeping system",
      package: package(),

      # Documentation
      docs: [
        main: "readme",
        logo: "priv/static/images/logo.png",
        extras: ["README.md", "LICENSE"],
        groups_for_modules: [
          "Core Types": [
            TidelandLedger.Amount,
            TidelandLedger.AccountPath
          ],
          Accounts: [
            TidelandLedger.Accounts,
            TidelandLedger.Accounts.Account
          ],
          Transactions: [
            TidelandLedger.Transactions,
            TidelandLedger.Transactions.Entry,
            TidelandLedger.Transactions.Position
          ],
          Users: [
            TidelandLedger.Users,
            TidelandLedger.Users.User
          ],
          Templates: [
            TidelandLedger.Templates,
            TidelandLedger.Templates.Template,
            TidelandLedger.Templates.TemplatePosition
          ]
        ]
      ],

      # Code coverage
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {TidelandLedger.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Phoenix and web dependencies
      {:phoenix, "~> 1.7.10"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_view, "~> 0.20.1"},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.24"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.6"},

      # Database and data handling
      {:ecto_sql, "~> 3.11"},
      {:ecto_sqlite3, "~> 0.12"},
      {:decimal, "~> 2.1"},

      # Authentication (Tideland Auth integration)
      {:req, "~> 0.4"},
      {:joken, "~> 2.6"},

      # Configuration
      {:toml, "~> 0.7"},

      # Development and testing
      {:floki, ">= 0.35.0", only: :test},
      {:ex_machina, "~> 2.7", only: :test},
      {:faker, "~> 0.18", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},

      # Security
      {:bcrypt_elixir, "~> 3.1"},
      {:argon2_elixir, "~> 4.0"},

      # Additional functionality
      {:nimble_csv, "~> 1.2"},
      {:timex, "~> 3.7"},
      {:money, "~> 1.12"},

      # Phoenix asset handling (no Node.js)
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Package information for Hex
  defp package do
    [
      name: "tideland_ledger",
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/tideland/ex-ledger",
        "Documentation" => "https://hexdocs.pm/tideland_ledger"
      },
      maintainers: ["Frank Mueller"]
    ]
  end

  # Dialyzer configuration
  defp dialyzer do
    [
      plt_add_apps: [:mix],
      ignore_warnings: ".dialyzer_ignore",
      flags: [:error_handling, :underspecs]
    ]
  end
end
