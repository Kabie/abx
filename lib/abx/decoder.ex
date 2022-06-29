defmodule ABX.Decoder do
  require Logger

  def decode_data(data, types) do
    with {:ok, values, _offset} <- decode_data(data, types, 0) do
      {:ok, values}
    end
  end

  def decode_data(data, types, offset) do
    types
    |> Enum.reduce_while({offset, []}, fn
      type, {off, acc} ->
        case decode_type(data, type, off) do
          {:ok, value, new_off} ->
            {:cont, {new_off, [value | acc]}}

          :error ->
            {:halt, :error}
        end
    end)
    |> case do
      :error -> :error
      {new_offset, values} -> {:ok, Enum.reverse(values), new_offset}
    end
  end

  @spec decode(binary(), term()) :: {:ok, term()} | :error
  def decode(data, type) do
    case decode_type(data, type, 0) do
      {:ok, value, _} -> {:ok, value}
      :error -> :error
    end
  end

  @spec decode_type(binary(), term(), integer()) :: {:ok, term(), binary()} | :error
  def decode_type(data, :address, offset) do
    <<_::bytes-size(offset), address::256, _::binary()>> = data
    case ABX.Types.Address.cast(address) do
      {:ok, address} ->
        {:ok, address, offset + 32}

      _ ->
        :error
    end
  end

  def decode_type(data, :bool, offset) do
    <<_::bytes-size(offset), bool::256, _::binary()>> = data
    case bool do
      1 -> {:ok, true, offset + 32}
      0 -> {:ok, false, offset + 32}
      _ -> :error
    end
  end

  for i <- 1..32 do
    def decode_type(data, {:bytes, unquote(i)}, offset) do
      <<_::bytes-size(offset), bytes::bytes-size(unquote(i)), _padding::bytes-size(unquote(32 - i)), _::bytes()>> = data
      {:ok, bytes, offset + 32}
    end
  end

  for i <- 1..31 do
    def decode_type(data, {:int, unquote(i * 8)}, offset) do
      <<_::bytes-size(offset), _::signed-unquote(256 - i * 8), int::signed-unquote(i * 8), _::bytes()>> = data
      {:ok, int, offset + 32}
    end
  end

  def decode_type(data, {:int, 256}, offset) do
    <<_::bytes-size(offset), int::signed-256, _::binary()>> = data
    {:ok, int, offset + 32}
  end

  for i <- 1..31 do
    def decode_type(data, {:uint, unquote(i * 8)}, offset) do
      <<_::bytes-size(offset), _::unquote(256 - i * 8), uint::unquote(i * 8), _::bytes()>> = data
      {:ok, uint, offset + 32}
    end
  end

  def decode_type(data, {:uint, 256}, offset) do
    <<_::bytes-size(offset), uint::256, _::binary()>> = data
    {:ok, uint, offset + 32}
  end

  def decode_type(data, {:tuple, inner_types}, offset) do
    with {:ok, values, new_offset} <- decode_data(data, inner_types, offset) do
      {:ok, List.to_tuple(values), new_offset}
    end
  end

  def decode_type(data, :bytes, offset) do
    <<_skipped::bytes-size(offset), len::256, bytes::bytes-size(len), _::bytes()>> = data
    {:ok, bytes, offset + pad_to_32(len) + 32}
  end

  def decode_type(data, :string, offset) do
    <<_skipped::bytes-size(offset), len::256, string::bytes-size(len), _::bytes()>> = data
    {:ok, string, offset + pad_to_32(len) + 32}
  end

  def decode_type(data, {:array, inner_type}, offset) do
    <<_skipped::bytes-size(offset), len::256, rest::bytes()>> = data

    case decode_data(rest, List.duplicate(inner_type, len), 0) do
      {:ok, values, inner_offset} ->
        {:ok, values, offset + inner_offset + 32}

      _ ->
        :error
    end
  end

  def decode_type(data, {:array, inner_type, len}, offset) do
    decode_data(data, List.duplicate(inner_type, len), offset)
  end

  # TODO
  def decode_type(_, type, _data) do
    throw({:unknow_type, type})
  end

  defp pad_to_32(n) do
    remaining = rem(n, 32)
    if remaining == 0 do
      n
    else
      n + 32 - remaining
    end
  end
end
