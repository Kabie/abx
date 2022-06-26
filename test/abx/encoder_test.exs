defmodule ABX.EncoderTest do
  use ExUnit.Case
  doctest ABX.Encoder

  alias ABX.Encoder

  test "encode int<X>" do
    int128_1 = <<0::signed-128, 1::signed-128>>
    assert Encoder.encode(1, {:int, 128}) == int128_1

    int128_neg1 = << -1::signed-128, -1::signed-128>>
    assert Encoder.encode(-1, {:int, 128}) == int128_neg1
  end

  test "encode bool" do
    assert Encoder.encode(true, :bool) == <<0x1::256>>
    assert Encoder.encode(false, :bool) == <<0x0::256>>
  end
end
