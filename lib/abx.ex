defmodule ABX do
  @moduledoc """
  Documentation for `ABX`.
  """

  @type types() :: ABX.Types.types()

  defdelegate encode(values, types), to: ABX.Encoder
  defdelegate decode(values, types), to: ABX.Decoder

  defmacro sigil_A({:<<>>, _, [addr_str]}, _mods) do
    {:ok, address} = ABX.Types.Address.cast(addr_str)
    Macro.escape(address)
  end
end
