defmodule ABX.Helpers do
  # ignore EIP-2930 for now
  @type txn_obj :: post_1559_txn() | legacy_post_155_txn() | legacy_pre_155_txn()
  @type post_1559_txn() :: %{
          chain_id: pos_integer(),
          nonce: non_neg_integer(),
          priority_fee: non_neg_integer(),
          gas_price: non_neg_integer(),
          gas_limit: non_neg_integer(),
          to: binary(),
          value: non_neg_integer(),
          data: binary()
        }
  @type legacy_post_155_txn() :: %{
          chain_id: pos_integer(),
          nonce: non_neg_integer(),
          gas_price: non_neg_integer(),
          gas_limit: non_neg_integer(),
          to: binary(),
          value: non_neg_integer(),
          data: binary()
        }
  @type legacy_pre_155_txn() :: %{
          nonce: non_neg_integer(),
          gas_price: non_neg_integer(),
          gas_limit: non_neg_integer(),
          to: binary(),
          value: non_neg_integer(),
          data: binary()
        }
  @type signed_raw_txn :: <<_::16, _::_*8>>

  @spec do_sign_transaction(txn_obj(), Ether.privkey()) :: signed_raw_txn()
  def do_sign_transaction(transaction, private_key) do
    case transaction do
      # Post EIP-1559, with format EIP-2718
      # TransactionType 2
      # TransactionPayload rlp([chain_id, nonce, priority_fee, gas_price, gas_limit, to, amount, data, access_list, y_parity, r, s])
      # we use empty access_list here for simplicity
      %{chain_id: chain_id, nonce: nonce, priority_fee: priority_fee, gas_price: gas_price, gas_limit: gas_limit, to: to, value: value, data: data} ->
        msg_to_sign = <<0x02>> <> ExRLP.encode([chain_id, nonce, priority_fee, gas_price, gas_limit, to, value, data, []])
        {r, s, v} = make_signature(msg_to_sign, private_key)
        y_parity = v - 27

        <<0x02>> <> ExRLP.encode([chain_id, nonce, priority_fee, gas_price, gas_limit, to, value, data, [], y_parity, r, s])

      # LegacyTransaction, post EIP-155
      # rlp([nonce, gasPrice, gasLimit, to, value, data, v, r, s])
      %{chain_id: chain_id, nonce: nonce, gas_price: gas_price, gas_limit: gas_limit, to: to, value: value, data: data} ->
        msg_to_sign = ExRLP.encode([nonce, gas_price, gas_limit, to, value, data, chain_id, 0, 0])
        {r, s, v} = make_signature(msg_to_sign, private_key)
        y_parity = v - 27
        v = chain_id * 2 + 35 + y_parity
        ExRLP.encode([nonce, gas_price, gas_limit, to, value, data, v, r, s])

      # LegacyTransaction, pre EIP-155
      %{nonce: nonce, gas_price: gas_price, gas_limit: gas_limit, to: to, value: value, data: data} ->
        msg_to_sign = ExRLP.encode([nonce, gas_price, gas_limit, to, value, data])
        {r, s, v} = make_signature(msg_to_sign, private_key)
        y_parity = v - 27
        v = y_parity + 27
        ExRLP.encode([nonce, gas_price, gas_limit, to, value, data, v, r, s])
    end
  end

  def sign_transaction(txn_obj, private_key, opts) do
    tco =
      txn_obj
      |> Map.merge(Map.new(opts))
      |> Map.put_new_lazy(:value, fn ->
        0
      end)
      |> Map.update(:to, <<>>, &normalize_address/1)
      |> Map.update(:data, <<>>, &normalize_data/1)

    signed_txn =
      do_sign_transaction(tco, private_key)
      |> Base.encode16()

    "0x" <> signed_txn
  end

  defp normalize_address(address) do
    case ABX.Types.Address.cast(address) do
      {:ok, address} -> address.bytes
      _ -> <<>>
    end
  end

  defp normalize_data(data) do
    case data do
      "0x" <> hex -> Base.decode16!(hex, case: :mixed)
      binary when is_binary(binary) -> binary
      _ -> <<>>
    end
  end

  def make_signature(msg_to_sign, private_key) do
    <<v, r::256, s::256>> =
      msg_to_sign
      |> Ether.keccak_256()
      |> Curvy.sign(private_key, compact: true, compressed: false, hash: false)

    {r, s, v}
  end

  def wallet_message(message) do
    "\x19Ethereum Signed Message:\n#{byte_size(message)}#{message}"
  end

  def wallet_sign(message, private_key) do
    {r, s, v} =
      wallet_message(message)
      |> make_signature(private_key)

    Base.encode16(<<r::256, s::256, v>>)
  end

  def wallet_recover_address(message, signature) do
    addr =
      wallet_message(message)
      |> recover_pubkey(signature)
      |> Ether.keccak_256()
      |> binary_part(12, 20)
      |> Base.encode16(case: :lower)

    "0x" <> addr
  end

  def recover_pubkey(message, signature) do
    {r, s, v} = unpack_signature(signature)
    Curvy.recover_key(<<v, r::256, s::256>>, message, hash: false)
    |> Curvy.Key.to_pubkey()
    |> binary_part(1, 64)
  end

  defp unpack_signature("0x" <> signature) do
    {:ok, <<r::256, s::256, v>>} = Base.decode16(signature, case: :mixed)
    {r, s, v}
  end
end
