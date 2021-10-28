defmodule Keccak do
  @moduledoc """
  Origin code is copied from https://github.com/dominicletz/exsha3/blob/master/lib/ex_sha3.ex

  Stripped to only support one algorithm:
  * KECCAK1600-f the original pre-fips version as used in Ethereum
  """

  inlines =
    for step <- 0..23 do
      {:"keccakf_exor_#{step}", 25}
    end ++
    for step <- 0..24 do
      {:"keccakf_#{step}", 25}
    end

  @compile {:inline, [{:absorb, 6} | inlines]}

  import Bitwise

  def keccak_256(bytes) do
    len = byte_size(bytes)

    <<0::200*8>>
    |> absorb(bytes, len, len, 136, 0x01)
    |> binary_part(0, 32)
  end

  defp keccakf(
         <<b0::64, b1::64, b2::64, b3::64,
           b4::64, b5::64, b6::64, b7::64,
           b8::64, b9::64, b10::64, b11::64,
           b12::64, b13::64, b14::64, b15::64,
           b16::64, b17::64, b18::64, b19::64,
           b20::64, b21::64, b22::64, b23::64,
           b24::64>>
       ) do
    keccakf_0(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24)
  end

  @full64 0xFFFFFFFFFFFFFFFF
  for {step, rc} <- [
        {0, 1},
        {1, 0x8082},
        {2, 0x800000000000808A},
        {3, 0x8000000080008000},
        {4, 0x808B},
        {5, 0x80000001},
        {6, 0x8000000080008081},
        {7, 0x8000000000008009},
        {8, 0x8A},
        {9, 0x88},
        {10, 0x80008009},
        {11, 0x8000000A},
        {12, 0x8000808B},
        {13, 0x800000000000008B},
        {14, 0x8000000000008089},
        {15, 0x8000000000008003},
        {16, 0x8000000000008002},
        {17, 0x8000000000000080},
        {18, 0x800A},
        {19, 0x800000008000000A},
        {20, 0x8000000080008081},
        {21, 0x8000000000008080},
        {22, 0x80000001},
        {23, 0x8000000080008008}
      ] do
    <<be_rc::64>> = <<rc::little-unsigned-size(64)>>

    defp unquote(:"keccakf_#{step}")(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24) do
      zero = exor(b0, b5, b10, b15, b20)
      one = exor(b1, b6, b11, b16, b21)
      two = exor(b2, b7, b12, b17, b22)
      three = exor(b3, b8, b13, b18, b23)
      four = exor(b4, b9, b14, b19, b24)
      tmp0 = bxor(four, rol_1(one))
      tmp1 = bxor(zero, rol_1(two))
      tmp2 = bxor(one, rol_1(three))
      tmp3 = bxor(two, rol_1(four))
      tmp4 = bxor(three, rol_1(zero))

      unquote(:"keccakf_exor_#{step}")(
        bxor(b0, tmp0),
        # b6 -> b1
        rol_44(bxor(b6, tmp1)),
        # b12 -> b2
        rol_43(bxor(b12, tmp2)),
        # b18 -> b3
        rol_21(bxor(b18, tmp3)),
        # b24 -> b4
        rol_14(bxor(b24, tmp4)),
        # b3 -> b5
        rol_28(bxor(b3, tmp3)),
        # b9 -> b6
        rol_20(bxor(b9, tmp4)),
        # b10 -> b7
        rol_3(bxor(b10, tmp0)),
        # b16 -> b8
        rol_45(bxor(b16, tmp1)),
        # b22 -> b9
        rol_61(bxor(b22, tmp2)),
        # b1 -> b10
        rol_1(bxor(b1, tmp1)),
        # b7 -> b11
        rol_6(bxor(b7, tmp2)),
        # b13 -> b12
        rol_25(bxor(b13, tmp3)),
        # b19 -> b13
        rol_8(bxor(b19, tmp4)),
        # b20 -> b14
        rol_18(bxor(b20, tmp0)),
        # b4 -> b15
        rol_27(bxor(b4, tmp4)),
        # b5 -> b16
        rol_36(bxor(b5, tmp0)),
        # b11 -> b17
        rol_10(bxor(b11, tmp1)),
        # b17 -> b18
        rol_15(bxor(b17, tmp2)),
        # b23 -> b19
        rol_56(bxor(b23, tmp3)),
        # b2 -> b20
        rol_62(bxor(b2, tmp2)),
        # b8 -> b21
        rol_55(bxor(b8, tmp3)),
        # b14 -> b22
        rol_39(bxor(b14, tmp4)),
        # b15 -> b23
        rol_41(bxor(b15, tmp0)),
        # b21 -> b24
        rol_2(bxor(b21, tmp1))
      )
    end

    defp unquote(:"keccakf_exor_#{step}")(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24) do
      # b0  -> b0 ^^^ b1 &&& b2 #0 ^^^ rc
      unquote(:"keccakf_#{step + 1}")(
        bxor(
          bxor(b0, band(bxor(b1, @full64), b2)),
          unquote(be_rc)
        ),
        # b6  -> b1 ^^^ b2 &&& b3 #1
        bxor(b1, band(bxor(b2, @full64), b3)),
        # b12 -> b2 ^^^ b3 &&& b4 #2
        bxor(b2, band(bxor(b3, @full64), b4)),
        # b18 -> b3 ^^^ b4 &&& b0 #3
        bxor(b3, band(bxor(b4, @full64), b0)),
        # b24 -> b4 ^^^ b0 &&& b1 #4
        bxor(b4, band(bxor(b0, @full64), b1)),
        # b3  -> b5 ^^^ b6 &&& b7 #0
        bxor(b5, band(bxor(b6, @full64), b7)),
        # b9  -> b6 ^^^ b7 &&& b8 #1
        bxor(b6, band(bxor(b7, @full64), b8)),
        # b10 -> b7 ^^^ b8 &&& b9 #2
        bxor(b7, band(bxor(b8, @full64), b9)),
        # b16 -> b8 ^^^ b9 &&& b6 #3
        bxor(b8, band(bxor(b9, @full64), b5)),
        # b22 -> b9 ^^^ b6 &&& b5 #4
        bxor(b9, band(bxor(b5, @full64), b6)),
        # b1  -> b10 ^^^ b11 &&& b12 #0
        bxor(b10, band(bxor(b11, @full64), b12)),
        # b7  -> b11 ^^^ b12 &&& b14 #1
        bxor(b11, band(bxor(b12, @full64), b13)),
        # b13 -> b12 ^^^ b14 &&& b15 #2
        bxor(b12, band(bxor(b13, @full64), b14)),
        # b19 -> b13 ^^^ b15 &&& b10 #3
        bxor(b13, band(bxor(b14, @full64), b10)),
        # b20 -> b14 ^^^ b10 &&& b11 #4
        bxor(b14, band(bxor(b10, @full64), b11)),
        # b4  -> b15 ^^^ b16 &&& b17 #0
        bxor(b15, band(bxor(b16, @full64), b17)),
        # b5  -> b16 ^^^ b17 &&& b18 #1
        bxor(b16, band(bxor(b17, @full64), b18)),
        # b11 -> b17 ^^^ b18 &&& b19 #2
        bxor(b17, band(bxor(b18, @full64), b19)),
        # b17 -> b18 ^^^ b19 &&& b15 #3
        bxor(b18, band(bxor(b19, @full64), b15)),
        # b23 -> b19 ^^^ b15 &&& b16 #4
        bxor(b19, band(bxor(b15, @full64), b16)),
        # b2  -> b20 ^^^ b21 &&& b22 #0
        bxor(b20, band(bxor(b21, @full64), b22)),
        # b8  -> b21 ^^^ b22 &&& b23 #1
        bxor(b21, band(bxor(b22, @full64), b23)),
        # b14 -> b22 ^^^ b23 &&& b24 #2
        bxor(b22, band(bxor(b23, @full64), b24)),
        # b15 -> b23 ^^^ b24 &&& b20 #3
        bxor(b23, band(bxor(b24, @full64), b20)),
        # b21 -> b24 ^^^ b20 &&& b21 #4
        bxor(b24, band(bxor(b20, @full64), b21))
      )
    end
  end

  defp keccakf_24(b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24) do
    <<b0::64, b1::64, b2::64, b3::64, b4::64, b5::64,
      b6::64, b7::64, b8::64, b9::64, b10::64, b11::64,
      b12::64, b13::64, b14::64, b15::64, b16::64, b17::64,
      b18::64, b19::64, b20::64, b21::64, b22::64, b23::64,
      b24::64>>
  end

  for n <- 1..63 do
    defp unquote(:"rol_#{n}")(x) do
      <<p1::unquote(n), p2::unquote(64 - n)>> = <<x::little-64>>
      <<result::little-64>> = <<p2::unquote(64 - n), p1::unquote(n)>>
      result
    end
  end

  defp exor(one, two, three, four, five) do
    0
    |> bxor(one)
    |> bxor(two)
    |> bxor(three)
    |> bxor(four)
    |> bxor(five)
  end

  defp xorin(dst, src, offset, len) do
    <<start::len*8, rest::binary()>> = dst
    <<_start::binary-size(offset), block::len*8, _rest::binary()>> = src
    <<bxor(block, start)::len*8, rest::binary()>>
  end

  defp xor(a, len, value) do
    <<start::binary-size(len), block::8, rest::binary()>> = a
    <<start::binary(), bxor(block, value), rest::binary()>>
  end

  # Fallbacks

  defp absorb(a, src, src_len, len, rate, delim) when len >= rate do
    a
    |> xorin(src, src_len - len, rate)
    |> keccakf()
    |> absorb(src, src_len, len - rate, rate, delim)
  end

  defp absorb(a, src, src_len, len, rate, delim) do
    a
    # Xor source the DS and pad frame.
    |> xor(len, delim)
    #
    |> xor(rate - 1, 0x80)
    |> xorin(src, src_len - len, len)
    # Apply P
    |> keccakf()
  end
end
