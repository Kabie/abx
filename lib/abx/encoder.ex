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

  # TODO:
  def encode(value, type) do
    Logger.error("Bad type: #{inspect(type)} #{inspect(value)}")
    <<0::256>>
  end
end
