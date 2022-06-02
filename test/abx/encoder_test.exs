defmodule ABX.EncoderTest do
  use ExUnit.Case
  doctest ABX.Encoder

  alias ABX.Encoder
  alias ABX.Types.Bytes

  test "encode int<X>" do
    int128_1 = <<0::signed-128, 1::signed-128>>
    assert Encoder.encode(1, {:int, 128}) == int128_1

    int128_neg1 = <<-1::signed-128, -1::signed-128>>
    assert Encoder.encode(-1, {:int, 128}) == int128_neg1
  end

  test "encode bool" do
    assert Encoder.encode(true, :bool) == <<1::256>>
    assert Encoder.encode(false, :bool) == <<0::256>>
  end

  test "encode bytes" do
    assert Encoder.encode(Bytes.cast!(<<0x0>>), :bytes) == <<1::256, 0::256>>
    assert Encoder.encode(Bytes.cast!(<<0x1>>), :bytes) == <<1::256, 0x1::8, 0::248>>
  end
end
