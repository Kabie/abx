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

  @spec sign_transaction(txn_obj(), Ether.privkey()) :: signed_raw_txn()
  def sign_transaction(transaction, private_key) do
    case transaction do
      # Post EIP-1559, with format EIP-2718
      # TransactionType 2
      # TransactionPayload rlp([chain_id, nonce, priority_fee, gas_price, gas_limit, to, amount, data, access_list, y_parity, r, s])
      # we use empty access_list here for simplicity
      %{chain_id: chain_id, nonce: nonce, priority_fee: priority_fee, gas_price: gas_price, gas_limit: gas_limit, to: to, value: value, data: data} ->
        msg_to_sign = <<0x02>> <> ExRLP.encode([chain_id, nonce, priority_fee, gas_price, gas_limit, to, value, data, []])
        {r, s, y_parity} = make_signature(msg_to_sign, private_key)

        <<0x02>> <> ExRLP.encode([chain_id, nonce, priority_fee, gas_price, gas_limit, to, value, data, [], y_parity, r, s])

      # LegacyTransaction, post EIP-155
      # rlp([nonce, gasPrice, gasLimit, to, value, data, v, r, s])
      %{chain_id: chain_id, nonce: nonce, gas_price: gas_price, gas_limit: gas_limit, to: to, value: value, data: data} ->
        msg_to_sign = ExRLP.encode([nonce, gas_price, gas_limit, to, value, data, chain_id, 0, 0])
        {r, s, y_parity} = make_signature(msg_to_sign, private_key)
        v = chain_id * 2 + 35 + y_parity
        ExRLP.encode([nonce, gas_price, gas_limit, to, value, data, v, r, s])

      # LegacyTransaction, pre EIP-155
      %{nonce: nonce, gas_price: gas_price, gas_limit: gas_limit, to: to, value: value, data: data} ->
        msg_to_sign = ExRLP.encode([nonce, gas_price, gas_limit, to, value, data])
        {r, s, y_parity} = make_signature(msg_to_sign, private_key)
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
      |> Map.update(:to, "", &normalize_binary/1)
      |> Map.update(:data, "", &normalize_binary/1)

    signed_txn =
      sign_transaction(tco, private_key)
      |> Base.encode16()

    "0x" <> signed_txn
  end

  defp normalize_binary("0x" <> hex) do
    Base.decode16!(hex, case: :mixed)
  end

  defp normalize_binary(binary) do
    binary
  end

  defp make_signature(msg_to_sign, private_key) do
    <<v, r::256, s::256>> =
      msg_to_sign
      |> Ether.keccak_256()
      |> Curvy.sign(private_key, compact: true, compressed: false, hash: false)

    {r, s, v - 27}
  end
end
