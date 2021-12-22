defmodule ABX.Types.Event do
  defstruct [
    :name,
    :anonymous,
    :inputs,
    :signature
  ]

  defmacro __using__(opts) do
    event = opts[:event]

    input_names =
      event.inputs
      |> Enum.map(&elem(&1, 0))

    event_module = Module.concat(__CALLER__.module, event.name)

    quote do
      defmodule unquote(event_module) do
        @moduledoc """
        #{unquote(to_definition(event))}

            #{unquote(event.signature)}
        """

        defstruct unquote(input_names)

        def abi() do
          unquote(Macro.escape(event))
        end
      end

      @events {unquote(event.signature), unquote(event_module)}
    end
  end

  @spec decode_log(atom(), %{data: String.t(), topics: [String.t()]}) :: map()
  def decode_log(event_module, %{data: data, topics: [signature | topics]}) do
    %__MODULE__{signature: ^signature, inputs: inputs} = event_module.abi()

    {indexed_inputs, data_inputs} =
      inputs
      |> Enum.split_with(&elem(&1, 2))

    indexed_field_types =
      indexed_inputs
      |> Enum.map(&elem(&1, 1))

    data_field_types =
      data_inputs
      |> Enum.map(&elem(&1, 1))

    indexed_fields =
      topics
      |> Enum.map(&Ether.unhex/1)
      |> Enum.zip(indexed_field_types)
      |> Enum.map(fn {bytes, type} ->
        {:ok, value} = ABX.Decoder.decode_type(bytes, type, <<>>)
        value
      end)

    {:ok, data_fields} = ABX.Decoder.decode_data(data, data_field_types)

    fields = build_event([], inputs, data_fields, indexed_fields)
    struct!(event_module, fields)
  end

  def build_event(fields, [], _data, _indexed), do: fields

  def build_event(fields, [{name, _type, true} | inputs], data, [value | indexed]) do
    build_event([{name, value} | fields], inputs, data, indexed)
  end

  def build_event(fields, [{name, _type, false} | inputs], [value | data], indexed) do
    build_event([{name, value} | fields], inputs, data, indexed)
  end

  def to_definition(%__MODULE__{name: name, inputs: inputs, anonymous: anonymous}) do
    param_types =
      inputs
      |> Enum.map(fn
        {name, type, indexed} ->
          type = ABX.type_name(type)
          if indexed do
            "#{type} indexed #{name}"
          else
            "#{type} #{name}"
          end
      end)
      |> Enum.join(", ")

    if anonymous do
      "#{name}(#{param_types}) anonymous"
    else
      "#{name}(#{param_types})"
    end
  end

end
