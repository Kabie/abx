defmodule Ether do
  @spec keccak_256(bytes :: binary()) :: <<_::_*32>>
  defdelegate keccak_256(bytes), to: :keccakf1600, as: :sha3_256

  @spec pubkey_create(bytes :: <<_::_*32>>) :: <<_::_*20>>
  def pubkey_create(bytes) do
    {:ok, pubkey} = :libsecp256k1.ec_pubkey_create(bytes, :uncompressed)
    pubkey
  end

  # Elixir
  @spec keccak_256(bytes :: binary(), format :: :bytes | :hex) :: <<_::_*32>> | <<_::_*64>>

  def keccak_256(bytes, :bytes) do
    keccak_256(bytes)
  end

  def keccak_256(bytes, :hex) do
    keccak_256(bytes)
    |> to_hex()
  end

  @spec pubkey_create(bytes :: binary(), format :: :bytes | :hex) :: <<_::_*20>> | <<_::_*42>>
  def pubkey_create(bytes, :bytes) do
    pubkey_create(bytes)
  end

  def pubkey_create(bytes, :hex) do
    pubkey_create(bytes)
    |> to_hex()
  end

  def address_of(priv_key) do
    <<4, public::bytes()>> = pubkey_create(priv_key)

    <<_::bytes-size(12), address::bytes-size(20)>> = keccak_256(public)
    to_hex(address)
  end

  def to_hex(bytes) do
    "0x" <> Base.encode16(bytes, case: :lower)
  end

  def unhex("0x" <> hex) do
    Base.decode16!(hex, case: :mixed)
  end

  def hexdigit("0x" <> hex) do
    String.to_integer(hex, 16)
  end
end
