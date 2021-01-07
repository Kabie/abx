defmodule ABX.Web3Adapter do
  @callback request({{atom(), [term()]}, [ABX.types()]}) :: {:ok, term()} | {:error, term()}
end
