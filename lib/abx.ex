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

  def parse_type(%{type: "tuple", components: inner_types}) do
    {:tuple, inner_types |> Enum.map(&parse_type/1)}
  end

  for {name, type} <- all_types do
    def parse_type(%{type: unquote(name)}) do
      unquote(type)
    end
  end

  def parse_type(%{type: type_name} = type_def) do
    case Regex.run(~r/(.*)\[(\d*)\]/, type_name) do
      [_, inner_type, ""] ->
        {:array, parse_type(%{type_def | type: inner_type})}

      [_, inner_type, n] ->
        {:array, parse_type(%{type_def | type: inner_type}), String.to_integer(n)}

      _ ->
        Logger.warn("Unsupported type name: #{type_name}")
        String.to_atom(type_name)
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

  def type_name({:tuple, inner_types}) do
    "(#{inner_types |> Enum.map(&type_name/1) |> Enum.join(",")})"
  end

  def type_name(type) do
    Logger.warn("Unsupported type: #{inspect(type)}")
    to_string(type)
  end

  defdelegate encode(values, types), to: ABX.Encoder
  defdelegate decode(values, types), to: ABX.Decoder

  defmacro sigil_A({:<<>>, _, [addr_str]}, _mods) do
    {:ok, address} = ABX.Types.Address.cast(addr_str)
    Macro.escape(address)
  end
end
