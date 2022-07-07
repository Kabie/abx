defmodule ABX.Decoder do
  require Logger

  @spec decode_type(binary(), term()) :: {:ok, term()} | :error
  def decode_type(data, type) do
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
        {:ok, address, 32}

      _ ->
        :error
    end
  end

  def decode_type(data, :bool, offset) do
    <<_::bytes-size(offset), bool::256, _::binary()>> = data

    case bool do
      1 -> {:ok, true, 32}
      0 -> {:ok, false, 32}
      _ -> :error
    end
  end

  for i <- 1..32 do
    def decode_type(data, {:bytes, unquote(i)}, offset) do
      <<_::bytes-size(offset), bytes::bytes-size(unquote(i)),
        _padding::bytes-size(unquote(32 - i)), _::bytes()>> = data

      {:ok, bytes, 32}
    end
  end

  for i <- 1..31 do
    def decode_type(data, {:int, unquote(i * 8)}, offset) do
      <<_::bytes-size(offset), _::unquote(256 - i * 8), int::signed-unquote(i * 8), _::bytes()>> =
        data

      {:ok, int, 32}
    end
  end

  def decode_type(data, {:int, 256}, offset) do
    <<_::bytes-size(offset), int::signed-256, _::binary()>> = data
    {:ok, int, 32}
  end

  for i <- 1..31 do
    def decode_type(data, {:uint, unquote(i * 8)}, offset) do
      <<_::bytes-size(offset), _::unquote(256 - i * 8), uint::unquote(i * 8), _::bytes()>> = data
      {:ok, uint, 32}
    end
  end

  def decode_type(data, {:uint, 256}, offset) do
    <<_::bytes-size(offset), uint::256, _::binary()>> = data
    {:ok, uint, 32}
  end

  def decode_type(data, {:tuple, inner_types}, offset) do
    <<_skipped::bytes-size(offset), inner_data::bytes()>> = data
    with {:ok, values, inner_offset} <- decode_data(inner_data, inner_types, 0) do
      {:ok, List.to_tuple(values), inner_offset}
    end
  end

  def decode_type(data, :bytes, offset) do
    <<_skipped::bytes-size(offset), len::256, bytes::bytes-size(len), _::bytes()>> = data
    {:ok, bytes, 32 + pad_to_32(len)}
  end

  def decode_type(data, :string, offset) do
    <<_skipped::bytes-size(offset), len::256, string::bytes-size(len), _::bytes()>> = data
    {:ok, string, 32 + pad_to_32(len)}
  end

  def decode_type(data, {:array, inner_type}, offset) do
    <<_skipped::bytes-size(offset), len::256, inner_data::bytes()>> = data

    case decode_data(inner_data, List.duplicate(inner_type, len), 0) do
      {:ok, values, inner_offset} ->
        {:ok, values, 32 + inner_offset}

      _ ->
        :error
    end
  end

  def decode_type(data, {:array, inner_type, len}, offset) do
    <<_::bytes-size(offset), inner_data::binary()>> = data
    decode_data(inner_data, List.duplicate(inner_type, len), 0)
  end

  # TODO: fixed types
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

  defp decode_data(data, types, start_offset) do
    types
    |> Enum.reduce_while({start_offset, []}, fn
      type, {base_offset, acc} ->
        case decode_type(data, type, base_offset) do
          {:ok, value, offset} ->
            {:cont, {base_offset + offset, [value | acc]}}

          :error ->
            {:halt, :error}
        end
    end)
    |> case do
      :error -> :error
      {new_offset, values} -> {:ok, Enum.reverse(values), new_offset}
    end
  end

  def decode_packed(data, types) do
    types
    |> Enum.reduce_while({0, []}, fn
      type, {base_offset, acc} ->
        # IO.inspect({type, base_offset, acc})
        if ABX.dynamic_type?(type) do
          <<_::bytes-size(base_offset), dynamic_offset::256, _::binary()>> = data

          case decode_type(data, type, dynamic_offset) do
            {:ok, value, _offset} ->
              {:cont, {base_offset + 32, [value | acc]}}

            :error ->
              {:halt, :error}
          end
        else
          case decode_type(data, type, base_offset) do
            {:ok, value, offset} ->
              {:cont, {base_offset + offset, [value | acc]}}

            :error ->
              {:halt, :error}
          end
        end
    end)
    |> case do
      :error -> :error
      {_offset, values} -> {:ok, Enum.reverse(values)}
    end
  end
end
