defmodule Machinist.MixProject do
  use Mix.Project

  @version "2.1.1"
  @repo_url "https://github.com/norbajunior/machinist"

  def project do
    [
      app: :machinist,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @repo_url,

      # Hex
      package: package(),

      # Docs
      name: "Machinist",
      description: "A small Elixir lib to write state machines",
      docs: [
        extras: ["README.md"],
        main: "Machinist",
        source_ref: "v#{@version}",
        source_url: @repo_url
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
