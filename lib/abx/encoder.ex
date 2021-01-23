defmodule ABX.Encoder do

  @spec encode(term(), ABX.types()) :: binary()

  def encode(integer_address, :address) when is_integer(integer_address) do
    <<0::96, integer_address::160>>
  end

  def encode(<<integer_address::160>>, :address) do
    <<0::96, integer_address::160>>
  end

  def encode("0x" <> <<bytes_address::bytes-size(40)>>, :address) do
    {:ok, address} = Base.decode16(bytes_address, case: :mixed)
    <<0::96, address::bytes()>>
  end

  def encode(integer, {:uint, bits}) when is_integer(integer) do
    padding = 256 - bits
    <<0::size(padding), integer::size(bits)>>
  end

  # TODO:
  def encode(_value, _type) do
    <<0::256>>
  end
end
