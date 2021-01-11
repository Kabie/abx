defmodule ABX.Web3Adapter do
  @type return_type() :: ABX.types() | :raw | :hex

  @callback request({{atom(), [term()]}, [return_type()]}) :: {:ok, term()} | {:error, term()}
end
