defmodule ABX do
  @moduledoc """
  Documentation for `ABX`.
  """

  require Logger

  basic_types =
    [:address, :bool, :string, :bytes]
    |> Enum.map(&{to_string(&1), &1})

  int_types =
    for i <- 1..32 do
      {"int#{i * 8}", {:int, i * 8}}
    end

  uint_types =
    for i <- 1..32 do
      {"uint#{i * 8}", {:uint, i * 8}}
    end

  bytes_types =
    for i <- 1..32 do
      {"bytes#{i}", {:bytes, i}}
    end

  all_types = basic_types ++ int_types ++ uint_types ++ bytes_types

  all_type_definitions =
    all_types
    |> Keyword.values()
    |> Enum.reduce(fn type, acc ->
      quote do
        unquote(type) | unquote(acc)
      end
    end)

  @type types() :: unquote(all_type_definitions)

  for {name, type} <- all_types do
    def parse_type(unquote(name)) do
      unquote(type)
    end
  end

  def parse_type(name) do
    case Regex.run(~r/(.*)\[(\d*)\]/, name) do
      [_, inner_type, ""] ->
        {:array, parse_type(inner_type)}

      [_, inner_type, n] ->
        {:array, parse_type(inner_type), String.to_integer(n)}

      _ ->
        Logger.warn("Unsupported type: #{name}")
        String.to_atom(name)
    end
  end

  for {name, type} <- all_types do
    def type_name(unquote(type)) do
      unquote(name)
    end
  end

  def type_name({:array, inner_type}) do
    type_name(inner_type) <> "[]"
  end

  def type_name({:array, inner_type, n}) do
    "#{type_name(inner_type)}[#{n}]"
  end

  def type_name(type) do
    Logger.warn("Unsupported type: #{type}")
    to_string(type)
  end
end
