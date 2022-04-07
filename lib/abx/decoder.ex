defmodule ABX.Decoder do
  require Logger

  def decode_data(data, types) do
    types
    |> Enum.with_index()
    |> Enum.map(fn {type, i} ->
      data
      |> binary_part(32 * i, 32)
      |> decode_type(type, data)
    end)
    |> Enum.reduce_while([], fn
      {:ok, value}, values -> {:cont, [value | values]}
      :error, _ -> {:halt, :error}
    end)
    |> case do
      :error -> :error
      values -> {:ok, Enum.reverse(values)}
    end
  end

  @spec decode_type(<<_::256>>, term(), binary()) :: {:ok, term()} | :error
  def decode_type(<<_padding::bytes-size(12), address::bytes-size(20)>>, :address, _data) do
    ABX.Types.Address.cast(address)
  end

  def decode_type(<<uint::256>>, {:uint, _size}, _data) do
    {:ok, uint}
  end

  def decode_type(<<bool::256>>, :bool, _data) do
    {:ok, bool > 0}
  end

  for i <- 1..32 do
    def decode_type(<<bytes::bytes-size(unquote(i)), _padding::bytes-size(unquote(32 - i))>>, {:bytes, unquote(i)}, _data) do
      ABX.Types.Bytes.cast(bytes)
    end
  end

  for i <- 1..31 do
    def decode_type(<<_::signed-unquote(256 - i * 8), n::signed-unquote(i * 8)>>, {:int, unquote(i * 8)}, _data) do
      {:ok, n}
    end
  end

  def decode_type(<<n::signed-256>>, {:int, 256}, _data) do
    {:ok, n}
  end

  def decode_type(<<offset::256>>, :bytes, data) do
    <<_skipped::bytes-size(offset), len::256, bytes::bytes-size(len), _::bytes()>> = data
    ABX.Types.Data.cast(bytes)
  end

  def decode_type(<<offset::256>>, :string, data) do
    <<_skipped::bytes-size(offset), len::256, string::bytes-size(len), _::bytes()>> = data
    {:ok, string}
  end

  def decode_type(<<offset::256>>, {:array, inner_type}, data) do
    <<_skipped::bytes-size(offset), len::256, rest::bytes()>> = data
    decode_data(rest, List.duplicate(inner_type, len))
  end

  def decode_type(_, {:array, inner_type, len}, data) do
    decode_data(data, List.duplicate(inner_type, len))
  end

  # TODO
  def decode_type(_, type, _data) do
    throw({:unknow_type, type})
  end
end
