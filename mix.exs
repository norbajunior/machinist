defmodule Machinist.MixProject do
  use Mix.Project

  @repo_url "https://github.com/norbajunior/machinist"

  def project do
    [
      app: :machinist,
      version: "0.2.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: @repo_url,

      # Hex
      package: package(),
      description: "A tiny Elixir lib to write state machines"
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
