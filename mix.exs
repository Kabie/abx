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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:keccakf1600, "~> 2.0", hex: :keccakf1600_otp23},
      {:ecto, "~> 3.5"},
      {:jason, "~> 1.2"},
      {:libsecp256k1, "~> 0.1.10"},
    ]
  end
end
