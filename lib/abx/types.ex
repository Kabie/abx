defmodule ABX.Types do
  require Logger

  def dynamic_type?(:string), do: true
  def dynamic_type?(:bytes), do: true
  def dynamic_type?({:array, _}), do: true
  def dynamic_type?({:array, type, _}), do: dynamic_type?(type)
  def dynamic_type?({:tuple, inner_types}), do: Enum.any?(inner_types, &dynamic_type?/1)
  def dynamic_type?(_type), do: false

  def head_size({:tuple, inner_types}) do
    if Enum.any?(inner_types, &dynamic_type?/1) do
      32
    else
      inner_types
      |> Enum.map(&head_size/1)
      |> Enum.sum()
    end
  end

  def head_size({:array, inner_type, n}) do
    if dynamic_type?(inner_type) do
      32
    else
      head_size(inner_type) * n
    end
  end

  def head_size(_), do: 32

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

  def parse(%{type: "tuple", components: inner_types}) do
    {:tuple, inner_types |> Enum.map(&parse/1)}
  end

  for {name, type} <- all_types do
    def parse(%{type: unquote(name)}) do
      unquote(type)
    end
  end

  def parse(%{type: type_name} = type_def) do
    case Regex.run(~r/(.*)\[(\d*)\]/, type_name) do
      [_, inner_type, ""] ->
        {:array, parse(%{type_def | type: inner_type})}

      [_, inner_type, n] ->
        {:array, parse(%{type_def | type: inner_type}), String.to_integer(n)}

      _ ->
        Logger.warn("Unsupported type name: #{type_name}")
        String.to_atom(type_name)
    end
  end

  for {name, type} <- all_types do
    def name(unquote(type)) do
      unquote(name)
    end
  end

  def name({:array, inner_type}) do
    name(inner_type) <> "[]"
  end

  def name({:array, inner_type, n}) do
    "#{name(inner_type)}[#{n}]"
  end

  def name({:tuple, inner_types}) do
    "(#{inner_types |> Enum.map(&name/1) |> Enum.join(",")})"
  end

  def name(type) do
    Logger.warn("Unsupported type: #{inspect(type)}")
    to_string(type)
  end
end
