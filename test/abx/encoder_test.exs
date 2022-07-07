defmodule ABX.EncoderTest do
  use ExUnit.Case
  doctest ABX.Encoder

  alias ABX.Encoder
  alias ABX.Types.{Address}
  import Ether, only: [to_hex: 1]

  test "encode address" do
    {:ok, addr} = Address.cast("0x1234567890123456789012345678901234567890")

    assert Encoder.encode_type(addr, :address) == <<0x1234567890123456789012345678901234567890::256>>
  end

  test "encode int<X>" do
    int128_1 = <<0::signed-128, 1::signed-128>>
    assert Encoder.encode_type(1, {:int, 128}) == int128_1

    int128_neg1 = << -1::signed-128, -1::signed-128>>
    assert Encoder.encode_type(-1, {:int, 128}) == int128_neg1
  end

  test "encode bool" do
    assert Encoder.encode_type(true, :bool) == <<0x1::256>>
    assert Encoder.encode_type(false, :bool) == <<0x0::256>>
  end

  test "pack types" do
    types = [:string, :address, {:uint, 256}, {:bytes, 32}, :address, :address]

    values = [
      "hello",
      "0x410bd673d011704ee5330f97e262e36c0da57619",
      31556952,
      "0x6fe099ad961068caf2f6571f80987d5c380028a7fb82e11908ab2cea0c33708e",
      "0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41",
      "0x410BD673d011704ee5330f97e262E36c0Da57619",
    ]

    assert Encoder.encode_packed(values, types) |> to_hex() == """
    0x\
    00000000000000000000000000000000000000000000000000000000000000c0\
    000000000000000000000000410bd673d011704ee5330f97e262e36c0da57619\
    0000000000000000000000000000000000000000000000000000000001e18558\
    6fe099ad961068caf2f6571f80987d5c380028a7fb82e11908ab2cea0c33708e\
    0000000000000000000000004976fb03c32e5b8cfe2b6ccb31c09ba78ebaba41\
    000000000000000000000000410bd673d011704ee5330f97e262e36c0da57619\
    0000000000000000000000000000000000000000000000000000000000000005\
    68656c6c6f000000000000000000000000000000000000000000000000000000\
    """

  end
end
