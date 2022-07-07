defmodule ABX.EncodingTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  import StreamData

  alias ABX.{Decoder, Encoder}
  import Bitwise, only: [bsl: 2]

  for type <- [:address, :bool, :string, :bytes] do
    def unquote(:"#{type}_type")() do
      constant(unquote(type))
    end
  end

  def int_types() do
    1..32
    |> Enum.map(&constant({:int, &1 * 8}))
    |> one_of()
  end

  def uint_types() do
    1..32
    |> Enum.map(&constant({:uint, &1 * 8}))
    |> one_of()
  end

  def bytes_types() do
    1..32
    |> Enum.map(&constant({:bytes, &1}))
    |> one_of()
  end

  def basic_types() do
    one_of([
      address_type(),
      bool_type(),
      int_types(),
      uint_types(),
      bytes_types(),
    ])
  end

  def abx_type() do
    one_of([
      address_type(),
      bool_type(),
      int_types(),
      uint_types(),
      bytes_types(),
      string_type(),
      bytes_type(),
      combo_types(),
    ])
  end

  def combo_types() do
    one_of([
      address_type(),
      bool_type(),
      int_types(),
      uint_types(),
      bytes_types(),
      string_type(),
      bytes_type(),
    ])
    |> tree(fn inner_data ->
      bind(positive_integer(), fn len ->
        one_of([
          map(inner_data, &{:array, &1}),
          map(inner_data, &{:array, &1, len}),
          map(list_of(inner_data), &{:tuple, &1}),
        ])
      end)
    end)
  end

  # Data gen
  def gen_data(:address) do
    binary(length: 20)
    |> map(fn bytes ->
      {:ok, address} = ABX.Types.Address.cast(bytes)
      address
    end)
  end

  def gen_data(:bool) do
    boolean()
  end

  def gen_data(:string) do
    string(:printable)
  end

  def gen_data(:bytes) do
    binary()
  end

  def gen_data({:int, n}) do
    integer(-bsl(1, n-1)..(bsl(1, n-1)-1))
  end

  def gen_data({:uint, n}) do
    integer(0..(bsl(1, n)-1))
  end

  def gen_data({:bytes, n}) do
    binary(length: n)
  end

  def gen_data({:array, inner_type}) do
    list_of(gen_data(inner_type))
  end

  def gen_data({:array, inner_type, len}) do
    list_of(gen_data(inner_type), length: len)
  end

  def gen_data({:tuple, inner_types}) do
    map(fixed_list(Enum.map(inner_types, &gen_data/1)), &List.to_tuple/1)
  end

  def gen_data(type) do
    IO.inspect({:not_impl, type})
    constant({:not_impl, type})
  end

  def abx_data(type_gen) do
    type_gen
    |> bind(fn type ->
      tuple({constant(type), gen_data(type)})
    end)
  end

  property "basic types" do
    check all {type, data} <- abx_data(basic_types()) do
      {:ok, encode_then_decode} =
        data
        |> Encoder.encode_type(type)
        |> Decoder.decode_type(type)

      assert encode_then_decode == data
    end
  end

  property "combo types" do
    check all {type, data} <- abx_data(combo_types()) do
      {:ok, encode_then_decode} =
        data
        |> Encoder.encode_type(type)
        |> Decoder.decode_type(type)

      assert encode_then_decode == data
    end
  end

  property "encode then decode" do
    check all {type, data} <- abx_data(abx_type()) do
      {:ok, encode_then_decode} =
        data
        |> Encoder.encode_type(type)
        |> Decoder.decode_type(type)

      assert encode_then_decode == data
    end
  end

  property "pack then unpack" do
    check all types_and_data <- list_of(abx_data(abx_type())) do
      {types, data} = Enum.unzip(types_and_data)

      {:ok, encode_then_decode} =
        data
        |> Encoder.encode_packed(types)
        |> Decoder.decode_packed(types)

      assert encode_then_decode == data
    end
  end
end
