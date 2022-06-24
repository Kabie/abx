defmodule ABX.MixProject do
  use Mix.Project

  def project do
    [
      app: :abx,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.7"},
      {:jason, "~> 1.2"},
      {:curvy, "~> 0.3.0"},
      {:ex_rlp, "~> 0.5.3"}
    ]
  end
end
