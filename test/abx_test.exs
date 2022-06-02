defmodule ABXTest do
  use ExUnit.Case
  doctest ABX

  import ABX

  describe "parse_type" do
    test "basic types" do
      assert parse_type(%{type: "address"}) == :address
      assert parse_type(%{type: "bool"}) == :bool
      assert parse_type(%{type: "bytes"}) == :bytes
    end

    test "uint<X>" do
      assert parse_type(%{type: "uint8"}) == {:uint, 8}
    end

    test "array type" do
      assert parse_type(%{type: "uint256[2]"}) == {:array, {:uint, 256}, 2}
      assert parse_type(%{type: "uint256[]"}) == {:array, {:uint, 256}}
      # unsupported type
      assert parse_type(%{type: "uint256["}) == :"uint256["
    end

    test "tuple type" do
      tpl = %{type: "tuple", components: [%{type: "address"}, %{type: "uint256"}]}
      assert parse_type(tpl) == {:tuple, [:address, {:uint, 256}]}
    end
  end

  describe "type_name" do
    test "basic types" do
      assert type_name(:address) == "address"
      assert type_name(:bool) == "bool"
      assert type_name(:bytes) == "bytes"
    end

    test "uint<X>" do
      assert type_name({:uint, 256}) == "uint256"
    end

    test "array type" do
      assert type_name({:array, {:uint, 256}, 2}) == "uint256[2]"
      assert type_name({:array, {:uint, 256}}) == "uint256[]"
    end

    test "tuple type" do
      assert type_name({:tuple, [:address, {:uint, 256}]}) == "(address,uint256)"
    end
  end
end
