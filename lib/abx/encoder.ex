defmodule ABX.Encoder do
  require Logger

  @spec encode_type(term(), ABX.types()) :: binary()
  def encode_type(value, type)

  def encode_type(address, :address) do
    {:ok, %{bytes: bytes}} = ABX.Types.Address.cast(address)
    <<0::96, bytes::bytes()>>
  end

  def encode_type(true, :bool), do: <<1::256>>
  def encode_type(false, :bool), do: <<0::256>>

  def encode_type(integer, {:uint, bits}) when is_integer(integer) do
    padding = 256 - bits
    <<0::size(padding), integer::size(bits)>>
  end

  def encode_type(integer, {:int, bits}) when is_integer(integer) do
    padding = 256 - bits
    if integer >= 0 do
      << 0::size(padding), integer::signed-size(bits)>>
    else
      << -1::size(padding), integer::signed-size(bits)>>
    end
  end

  def encode_type(bytes_n, {:bytes, n}) when is_binary(bytes_n) and n in 1..32 do
    {:ok, %{bytes: bytes, size: ^n}} = ABX.Types.Bytes.cast(bytes_n)
    padding = 32 - n
    <<bytes::bytes(), 0::padding*8>>
  end

  def encode_type(binary, type) when type in [:bytes, :string] and is_binary(binary) do
    len = byte_size(binary)
    pad_len = calc_padding(len)
    encode_type(len, {:uint, 256}) <> binary <> <<0::pad_len*8>>
  end

  def encode_type(string, :string) when is_binary(string) do
    len = byte_size(string)
    pad_len = calc_padding(len)
    encode_type(len, {:uint, 256}) <> string <> <<0::pad_len*8>>
  end

  def encode_type(list, {:array, inner_type}) when is_list(list) do
    data =
      for value <- list, into: <<>> do
        encode_type(value, inner_type)
      end

    encode_type(length(list), {:uint, 256}) <> data
  end

  def encode_type(list, {:array, inner_type, n}) when is_list(list) and length(list) == n do
    for value <- list, into: <<>> do
      encode_type(value, inner_type)
    end
  end

  # TODO: use encode_packed
  def encode_type(tuple, {:tuple, inner_types}) when is_tuple(tuple) and is_list(inner_types) and tuple_size(tuple) == length(inner_types) do
    for {value, inner_type} <- tuple |> Tuple.to_list |> Enum.zip(inner_types), into: <<>> do
      encode_type(value, inner_type)
    end
  end

  # TODO: more types
  def encode_type(value, type) do
    Logger.error("Unsupported type #{inspect(type)}: #{inspect(value)}")
    <<0::256>>
  end


  @spec encode_packed([term()], [ABX.types()]) :: binary()
  def encode_packed(values, types) when length(values) == length(types) do
    tail_offset =
      types
      |> Enum.map(&head_size/1)
      |> Enum.sum()

    {head, tail} =
      Enum.zip(values, types)
      |> Enum.reduce({"", ""}, fn {value, type}, {head, tail} ->
        encoded = encode_type(value, type)
        if ABX.dynamic_type?(type) do
          offset = encode_type(tail_offset + byte_size(tail), {:uint, 256})
          {head <> offset, tail <> encoded}
        else
          {head <> encoded, tail}
        end
      end)

    head <> tail
  end

  defp head_size({:tuple, inner_types}) do
    if Enum.any?(inner_types, &ABX.dynamic_type?/1) do
      32
    else
      inner_types
      |> Enum.map(&head_size/1)
      |> Enum.sum()
    end
  end

  defp head_size({:array, inner_type, n}) do
    if ABX.dynamic_type?(inner_type) do
      32
    else
      32 * n
    end
  end

  defp head_size(_), do: 32

  defp calc_padding(n) do
    remaining = rem(n, 32)
    if remaining == 0 do
      0
    else
      32 - remaining
    end
  end
end
