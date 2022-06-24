defmodule ABX.Types.Data do
  @moduledoc """
  Variable length binary, align to 32 bytes.
  """

  use Ecto.Type

  defstruct [:bytes]

  @type t :: %__MODULE__{
          bytes: binary()
        }

  @impl Ecto.Type
  @spec type() :: :bytea
  def type, do: :bytea

  @impl Ecto.Type
  @spec load(term()) :: {:ok, t()} | :error
  def load(<<"0x", hex_string::bytes-unit(256)>>), do: cast_hex(hex_string)
  def load(<<bytes::bytes-unit(256)>>), do: {:ok, %__MODULE__{bytes: bytes}}
  def load(_), do: :error

  @impl Ecto.Type
  @spec dump(t()) :: {:ok, binary()} | :error
  def dump(%__MODULE__{bytes: <<bytes::bytes-unit(256)>>}), do: {:ok, bytes}
  def dump(_), do: :error

  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(<<"0x", hex_string::bytes-unit(256)>>), do: cast_hex(hex_string)
  def cast(<<bytes::bytes-unit(256)>>), do: {:ok, %__MODULE__{bytes: bytes}}
  def cast(%__MODULE__{bytes: <<_::bytes()>>} = term), do: {:ok, term}
  def cast(_term), do: :error

  defp cast_hex(hex_string) do
    case Base.decode16(hex_string, case: :mixed) do
      {:ok, bytes} ->
        {:ok, %__MODULE__{bytes: bytes}}

      _ ->
        :error
    end
  end

  def to_string(%__MODULE__{bytes: nil}) do
    "0x"
  end

  def to_string(%__MODULE__{bytes: <<bytes::bytes()>>}) do
    "0x" <> Base.encode16(bytes, case: :lower)
  end

  def to_inspect(hash) do
    "Data<#{__MODULE__.to_string(hash)}>"
  end

  defimpl String.Chars do
    def to_string(hash) do
      @for.to_string(hash)
    end
  end

  defimpl Inspect do
    def inspect(hash, _opts) do
      @for.to_inspect(hash)
    end
  end

  defimpl Jason.Encoder do
    alias Jason.Encode

    def encode(hash, opts) do
      hash
      |> to_string()
      |> Encode.string(opts)
    end
  end
end
