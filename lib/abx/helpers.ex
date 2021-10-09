defmodule ABX.Helpers do
  def sign_transaction(txn_call_obj, private_key, opts) do
    tco =
      txn_call_obj
      |> Map.merge(Map.new(opts))

    tco =
      tco
      |> Map.put_new_lazy(:value, fn ->
        0
      end)

    signed_txn =
      sign_transaction(tco, private_key)
      |> Base.encode16()

    "0x" <> signed_txn
  end

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

  def make_signature(msg_to_sign, private_key) do
    {:ok, <<r::256, s::256>>, y_parity} =
      msg_to_sign
      |> Ether.keccak_256()
      |> :libsecp256k1.ecdsa_sign_compact(private_key, :default, <<>>)

    {r, s, y_parity}
  end
end
