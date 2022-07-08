defmodule ABX.Types do

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

end
