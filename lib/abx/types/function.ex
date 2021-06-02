defmodule ABX.Types.Function do
  defstruct [
    :name,
    :inputs,
    :outputs,
    :constant,
    :payable,
    :state_mutability
  ]

  alias ABX.Types.{Address, Hash, Data, HexDigit}

  defmacro __using__(opts) do
    function = opts[:function]

    define_func_call(function)
  end

  def method_signature(%{name: name, inputs: inputs}) do
    param_types =
      inputs
      |> Enum.map(&input_type/1)
      |> Enum.join(",")

    "#{name}(#{param_types})"
  end

  def input_type({_, type}) do
    ABX.type_name(type)
  end

  def define_func_call(%__MODULE__{} = abi) do
    signature = method_signature(abi)

    abi_name =
      signature
      |> String.replace(["(", ")", "[", "]", ","], "_")
      |> String.to_atom()

    params =
      abi.inputs
      |> Enum.with_index(1)
      |> Enum.map(fn {input, i} ->
        var_name =
          case elem(input, 0) do
            :"" -> :"arg#{i}"
            name -> name
          end

        Macro.var(var_name, nil)
      end)

    return_types =
      abi.outputs
      |> Enum.map(&elem(&1, 1))

    case abi.state_mutability do
      :view ->
        define_immutable_call(abi, signature, abi_name, params, return_types)

      :pure ->
        define_immutable_call(abi, signature, abi_name, params, return_types)

      :nonpayable ->
        define_transaction_call(abi, signature, abi_name, params)

      :payable ->
        define_transaction_call(abi, signature, abi_name, params)

      _ ->
        nil
    end
  end

  def define_transaction_call(abi, signature, abi_name, params) do
    selector =
      signature
      |> Ether.keccak_256(:hex)
      |> binary_part(0, 10)

    quote generated: true do
      @doc unquote(signature)
      def unquote(abi_name)(unquote_splicing(params), opts) do
        unquote(__MODULE__).tco(
          unquote(params),
          unquote(Macro.escape(abi)),
          unquote(selector),
          Keyword.merge([to: @contract_address], opts)
        )
      end
    end
  end

  def define_immutable_call(abi, signature, abi_name, params, return_types) do
    selector =
      signature
      |> Ether.keccak_256(:hex)
      |> binary_part(0, 10)

    return_type_string =
      return_types
      |> Enum.map(&ABX.type_name/1)
      |> Enum.join(",")

    doc = """
    #{signature} returns (#{return_type_string})
    """

    quote generated: true do
      @doc unquote(doc)
      def unquote(abi_name)(unquote_splicing(params), opts) do
        block =
          Keyword.get(opts, :block, :latest)
          |> unquote(__MODULE__).normalize_block_number()

        tco =
          unquote(__MODULE__).tco(
            unquote(params),
            unquote(Macro.escape(abi)),
            unquote(selector),
            Keyword.merge([to: @contract_address], opts)
          )

        {{:eth_call, [tco, block]}, unquote(return_types)}
      end
    end
  end

  def tco(inputs, function, selector, opts) do
    input_types = Enum.map(function.inputs, &elem(&1, 1))

    params_data =
      encode_inputs(inputs, input_types)
      |> Base.encode16(case: :lower)

    data = selector <> params_data

    to =
      Keyword.get(opts, :to)
      |> normalize_address()

    Map.new(opts)
    |> Map.take([:from, :gas, :gas_price, :gas_limit, :value, :nonce])
    |> Map.merge(%{to: to, data: data})
  end

  def encode_inputs(inputs, input_types) do
    encoded_inputs =
      for {value, type} <- Enum.zip(inputs, input_types) do
        ABX.Encoder.encode(value, type)
      end

    ABX.Encoder.pack(encoded_inputs, input_types)
  end

  def cast_inputs(inputs, types) do
    inputs
    |> Enum.zip(types)
    |> Enum.map(fn
      {input, type} -> cast_input(input, type)
    end)
  end

  defp cast_input(address, :address) do
    with {:ok, %{bytes: bytes}} <- Address.cast(address) do
      bytes
    end
  end

  defp cast_input(bytes_value, {:bytes, _}) do
    with {:ok, %{bytes: bytes}} <- Hash.cast(bytes_value) do
      bytes
    end
  end

  defp cast_input(bytes_value, :bytes) do
    with {:ok, %{bytes: bytes}} <- Data.cast(bytes_value) do
      bytes
    end
  end

  defp cast_input(int_value, {int_type, _}) when int_type in [:int, :uint] do
    with {:ok, %{value: value}} <- HexDigit.cast(int_value) do
      value
    end
  end

  defp cast_input(values, {:array, inner_type}) do
    Enum.map(values, &cast_input(&1, inner_type))
  end

  defp cast_input(values, {:array, inner_type, _n}) do
    Enum.map(values, &cast_input(&1, inner_type))
  end

  defp cast_input(values, {:tuple, types}) do
    values
    |> Tuple.to_list()
    |> Enum.zip(types)
    |> Enum.map(fn {value, type} -> cast_input(value, type) end)
    |> List.to_tuple()
  end

  defp cast_input(input, _type), do: input

  def normalize_address(address) do
    {:ok, addr} = Address.cast(address)
    to_string(addr)
  end

  def normalize_block_number(<<"0x", _::binary()>> = block), do: block

  def normalize_block_number(block) when is_integer(block),
    do: "0x" <> Integer.to_string(block, 16)

  def normalize_block_number(block) when block in [:latest, :earliest, :pending], do: block
end
