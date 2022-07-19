defmodule PlugLimit.MixProject do
  use Mix.Project

  @source_url "https://github.com/Recruitee/plug_limit"
  @version "0.1.0"

  def project do
    [
      app: :plug_limit,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      name: "PlugLimit",
      description: "Rate limiting Plug module based on Redis Lua scripting"
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:plug, "~> 1.10"},
      {:ex_doc, "~> 0.28.0", only: :dev, runtime: false},
      {:eredis, "~> 1.4", only: :test},
      {:redix, "~> 1.1", only: :test}
    ]
  end

  defp package do
    [
      files: ~w(lib lua .formatter.exs mix.exs CHANGELOG.md README.md LIMITERS.md),
      maintainers: ["Recruitee", "Andrzej Magdziarz"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      extras: ["README.md", "LIMITERS.md"],
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end
