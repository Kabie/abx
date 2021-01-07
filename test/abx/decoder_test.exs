defmodule ABX.DecoderTest do
  use ExUnit.Case
  doctest ABX.Decoder

  alias ABX.Decoder

  test "decode_type" do
    assert Decoder.decode_type(<<1::256>>, :address, <<1::256>>) == {:ok, <<1::160>>}
  end
end
