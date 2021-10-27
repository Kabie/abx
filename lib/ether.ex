defmodule Ether do
  @spec keccak_256(bytes :: binary()) :: <<_::_*32>>
  defdelegate keccak_256(bytes), to: :keccakf1600, as: :sha3_256

  @type privkey() :: <<_::_*32>> | <<_::_*64>> | pos_integer()
  @type pubkey() :: <<_::_*65>>
  @type address() :: <<_::_*20>> | <<_::_*42>>

  @spec pubkey_create(privkey :: privkey()) :: pubkey()
  def pubkey_create(privkey) do
    {:ok, privkey_bytes} = parse_privkey(privkey)
    {pubkey, _} = :crypto.generate_key(:ecdh, :secp256k1, privkey_bytes)
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

  @spec pubkey_create(privkey :: privkey(), format :: :bytes | :hex) :: pubkey()
  def pubkey_create(privkey, :bytes) do
    pubkey_create(privkey)
  end

  def pubkey_create(privkey, :hex) do
    pubkey_create(privkey)
    |> to_hex()
  end

  def parse_privkey(private_key) do
    case private_key do
      <<_::binary-size(32)>> ->
        {:ok, private_key}

      <<encoded_private_key::binary-size(64)>> ->
        Base.decode16(encoded_private_key, case: :mixed)

      pkey when is_integer(pkey) ->
        {:ok, <<pkey::256>>}

      _ ->
        :error
    end
  end

  def address_of(priv_key) do
    <<4, public::bytes()>> = pubkey_create(priv_key)

    <<_::bytes-size(12), address::bytes-size(20)>> = keccak_256(public)
    to_hex(address)
  end

  def to_hex(bytes) when is_binary(bytes) do
    "0x" <> Base.encode16(bytes, case: :lower)
  end

  def unhex("0x" <> hex) do
    Base.decode16!(hex, case: :mixed)
  end

  def hexdigit("0x" <> hex) do
    String.to_integer(hex, 16)
  end

  def make_key() do
    :crypto.strong_rand_bytes(32)
    |> make_key()
  end

  def make_key(privkey) do
    {:ok, pkey} = ABX.Types.Hash.cast(privkey)
    {address_of(pkey.bytes), Base.encode16(pkey.bytes, case: :lower)}
  end

  def search_address(prefix, suffix, tries \\ 10000) do
    _search_address(String.downcase(prefix), String.downcase(suffix), tries)
  end

  defp _search_address(_prefix, _suffix, 0), do: nil

  defp _search_address(prefix, suffix, tries) do
    privkey = :crypto.strong_rand_bytes(32)
    "0x" <> address = address_of(privkey)

    if String.starts_with?(address, prefix) and
         String.ends_with?(address, suffix) do
      {address_of(privkey), Base.encode16(privkey)}
    else
      _search_address(prefix, suffix, tries - 1)
    end
  end

  def para_search_address(prefix, suffix, n \\ 1, concurrency \\ 4, tries \\ 10_000) do
    1..concurrency
    |> Task.async_stream(
      fn _ ->
        search_address(prefix, suffix, tries)
      end,
      max_concurrency: concurrency,
      ordered: false,
      timeout: :infinity
    )
    |> Stream.reject(fn {_, result} -> is_nil(result) end)
    |> Stream.map(fn {_, {addr, priv}} ->
      {addr, priv}
    end)
    |> Enum.take(n)
  end
end
