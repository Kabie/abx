defmodule ABX.Compiler do
  defmacro __using__(opts) do
    abi_file = opts[:abi_file]
    abis = parse_abi_file(abi_file)
    contract_address = opts[:contract_address]

    event_definitions =
      for %ABX.Types.Event{} = event_abi <- abis do
        define_event(event_abi)
      end

    function_definitions =
      for %ABX.Types.Function{} = function_abi <- abis do
        define_function(function_abi)
      end

    quote do
      @external_resource unquote(abi_file)
      @abis unquote(Macro.escape(abis))
      @contract_address unquote(contract_address)

      def abis() do
        @abis
      end
      def abi_file, do: @external_resource

      @name __MODULE__
      |> Module.split()
      |> List.last()
      # |> Macro.underscore()
      |> String.to_atom()
      def contract_name, do: @name

      def address() do
        @contract_address
      end

      Module.register_attribute(__MODULE__, :events, accumulate: true)
      unquote(event_definitions)

      @events_lookup Map.new(@events)

      def lookup(event_signature) do
        @events_lookup[event_signature]
      end

      def decode_event(%{topics: [event_signature | _]} = log) do
        case lookup(event_signature) do
          nil ->
            nil

          event ->
            ABX.Types.Event.decode_log(event, log)
        end
      end

      unquote(function_definitions)
    end
  end

  require Logger

  def parse_abi_file(file_name) do
    file_name
    |> File.read!()
    |> Jason.decode!(keys: :atoms)
    |> Enum.map(&parse_abi/1)
    |> Enum.reject(&is_nil/1)
  end

  def parse_abi(%{type: "constructor"} = abi) do
    %ABX.Types.Constructor{
      inputs: parse_params(abi.inputs),
      payable: abi[:payable],
      state_mutability: parse_state_mutability(abi[:stateMutability])
    }
  end

  def parse_abi(%{type: "event"} = abi) do
    inputs = parse_event_params(abi.name, abi.inputs)

    %ABX.Types.Event{
      name: String.to_atom(abi.name),
      anonymous: abi.anonymous,
      inputs: inputs,
      signature: calc_signature(abi.name, inputs)
    }
  end

  def parse_abi(%{type: "function"} = abi) do
    %ABX.Types.Function{
      name: String.to_atom(abi.name),
      inputs: parse_params(abi.inputs),
      outputs: parse_params(abi.outputs),
      constant: abi[:constant],
      payable: abi[:payable],
      state_mutability: parse_state_mutability(abi[:stateMutability])
    }
  end

  # receive & fallback
  def parse_abi(%{type: _}) do
    nil
  end

  def calc_signature(name, inputs) do
    [name, ?(, inputs |> Enum.map(&ABX.type_name(elem(&1, 1))) |> Enum.join(","), ?)]
    |> IO.iodata_to_binary()
    |> Ether.keccak_256(:hex)
  end

  def parse_event_params(event_name, type_defs) do
    type_defs
    |> Enum.map(fn %{name: name, indexed: indexed} = type_def ->
      if name == "" do
        Logger.error("Event #{inspect(event_name)}: empty param name")
      end

      {String.to_atom(name), ABX.parse_type(type_def), [indexed: indexed]}
    end)
  end

  def parse_params(type_defs) do
    type_defs
    |> Enum.map(fn %{name: name} = type_def ->
      param =
        name
        |> String.trim_leading("_")
        |> String.to_atom()

      {param, ABX.parse_type(type_def)}
    end)
  end

  def parse_state_mutability("view"), do: :view
  def parse_state_mutability("pure"), do: :pure
  def parse_state_mutability("payable"), do: :payable
  def parse_state_mutability("nonpayable"), do: :nonpayable
  def parse_state_mutability(_), do: :view

  # definitions
  def define_event(%ABX.Types.Event{} = event) do
    quote do
      use ABX.Types.Event, event: unquote(event)
    end
  end

  def define_function(%ABX.Types.Function{} = function) do
    quote do
      use ABX.Types.Function, function: unquote(function)
    end
  end
end
