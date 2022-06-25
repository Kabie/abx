defmodule ABX.Tokens.ERC20Test do
  use ExUnit.Case

  alias ABX.Tokens.ERC20

  test "encode int<X>" do
    assert ERC20.abi_file() == ["priv/contracts/ERC20.abi.json"]
    assert ERC20.contract_name() == :ERC20
    assert ERC20.Transfer.contract() == ERC20

    assert ERC20.Transfer.signature() ==
             "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

    assert ERC20.Transfer.abi() == %ABX.Types.Event{
             anonymous: false,
             inputs: [
               {:from, :address, [indexed: true]},
               {:to, :address, [indexed: true]},
               {:value, {:uint, 256}, [indexed: false]}
             ],
             name: :Transfer,
             signature: "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
           }
  end
end
