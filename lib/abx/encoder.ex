defmodule ABX.Encoder do
  require Logger

  @spec encode(term(), ABX.types()) :: binary()

  def encode(address, :address) do
    {:ok, %{bytes: bytes}} = ABX.Types.Address.cast(address)
    <<0::96, bytes::bytes()>>
  end

  def encode(integer, {:uint, bits}) when is_integer(integer) do
    padding = 256 - bits
    <<0::size(padding), integer::size(bits)>>
  end

  def encode(list, {:array, inner_type}) when is_list(list) do
    data =
      for value <- list, into: <<>> do
        encode(value, inner_type)
      end

    encode(length(list), {:uint, 256}) <> data
  end

  # TODO: more types
  def encode(value, type) do
    Logger.error("Unsupported type #{inspect(type)}: #{inspect(value)}")
    <<0::256>>
  end


  @spec pack([binary()], [ABX.types()]) :: binary()

  def pack(encoded_inputs, input_types) do
    pack(encoded_inputs, input_types, length(encoded_inputs) * 32, <<>>, <<>>)
  end

  defp pack([], [], _base_offset, inplace_data, data) do
    inplace_data <> data
  end

  defp pack([encoded | encoded_inputs], [{:array, _} | input_types], base_offset, inplace_data, data) do
    offset = encode(base_offset + byte_size(data), {:uint, 256})
    pack(encoded_inputs, input_types, base_offset, inplace_data <> offset, data <> encoded)
  end

  defp pack([encoded | encoded_inputs], [_static_type | input_types], base_offset, inplace_data, data) do
    pack(encoded_inputs, input_types, base_offset, inplace_data <> encoded, data)
  end
end
