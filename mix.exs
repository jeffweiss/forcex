defmodule Forcex.Mixfile do
  use Mix.Project

  @description """
    Elixir library for the Force.com / SalesForce / SFDC REST API
  """

  def project do
    [
      app: :forcex,
      version: "0.2.2",
      elixir: "~> 1.0",
      name: "Forcex",
      description: @description,
      package: package,
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        "coveralls": :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.post": :test,
        "docs": :docs,
        "hex.docs": :docs,
      ],
      deps: deps,
   ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :httpoison]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:httpoison, "~> 0.8"},
      {:exjsx, "~> 3.1"},
      {:timex, "~> 2.0"},
      {:excoveralls, "~> 0.5", only: :test},
      {:ex_doc, "~> 0.11.4", only: :docs},
      {:earmark, "~> 0.2", only: :docs},
    ]
  end

  defp package do
    [ maintainers: ["Jeff Weiss"],
      licenses: ["MIT"],
      links: %{"Github" => "https://github.com/jeffweiss/forcex"} ]
  end
end
