defmodule ABX.DecoderTest do
  use ExUnit.Case
  doctest ABX.Decoder

  alias ABX.Decoder
  alias ABX.Types.Address

  test "decode_type" do
    assert Decoder.decode_type(<<1::256>>, :address, 0) |> elem(1) == Address.cast(1) |> elem(1)
  end

  test "decode int<X>" do
    int128_1 = <<0::signed-128, 1::signed-128>>
    assert Decoder.decode_type(int128_1, {:int, 128}, 0) == {:ok, 1, 32}

    int128_neg1 = << -1::signed-128, -1::signed-128>>
    assert Decoder.decode_type(int128_neg1, {:int, 128}, 0) == {:ok, -1, 32}
  end
end
