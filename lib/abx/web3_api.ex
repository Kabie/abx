defmodule ABX.Web3API do
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__)

      def_web3 :eth_getTransactionByHash, [tx], fn txn ->
        txn
        |> Map.update!(:gas, &hex_number/1)
        |> Map.update!(:gasPrice, &hex_number/1)
        |> Map.update!(:nonce, &hex_number/1)
        |> Map.update!(:blockNumber, &hex_number/1)
        |> Map.update!(:transactionIndex, &hex_number/1)
      end

      def_web3 :eth_blockNumber, [], :hex

      def_web3 :eth_gasPrice, [], :hex

      def_web3 :eth_getTransactionCount, [address, block], :hex
    end
  end

  defmacro def_web3(method, params, return_type) do

    quote do
      def unquote(method)(web3_endpoint, unquote_splicing(params)) do
        request(web3_endpoint, {{unquote(method), unquote(params)}, unquote(return_type)})
      end
    end

  end


  def hex_number(nil) do
    nil
  end

  def hex_number("0x" <> hex_string) do
    String.to_integer(hex_string, 16)
  end
end
