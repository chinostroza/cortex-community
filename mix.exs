defmodule CortexCommunity.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/chinostroza/cortex_community"

  def project do
    [
      app: :cortex_community,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      releases: releases(),
      description: "Open-source AI gateway powered by Cortex Core",
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      mod: {CortexCommunity.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core AI functionality
      {:cortex_core, "~> 1.0.2"},
      # Or for local development:
      # {:cortex_core, path: "../cortex_core"},

      # Phoenix Framework
      {:phoenix, "~> 1.7.10"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},

      # HTTP & API
      {:plug_cowboy, "~> 2.5"},
      {:cors_plug, "~> 3.0"},
      {:jason, "~> 1.2"},
      {:gettext, "~> 0.24"},

      # Monitoring & Telemetry (basic)
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},

      # Development & Testing
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      test: ["test"],
      "test.coverage": ["test --cover"],
      quality: ["format", "credo --strict"],
      server: ["phx.server"]
    ]
  end

  defp releases do
    [
      cortex_community: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        steps: [:assemble, :tar],
        path: "releases",
        cookie: Base.encode64(:crypto.strong_rand_bytes(32))
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "priv/static/images/logo.png",
      extras: ["README.md", "guides/deployment.md", "guides/configuration.md"]
    ]
  end
end
