defmodule ABX.Types.Address do
  @moduledoc """
  Ethereum address, 20 bytes.
  """

  use Ecto.Type

  @hash_size 20
  @bytes_size @hash_size * 2
  @bits_size @hash_size * 8

  defstruct [:bytes]

  @type t :: %__MODULE__{
          bytes: <<_::_*unquote(@hash_size)>>
        }

  @impl Ecto.Type
  @spec type() :: :bytea
  def type, do: :bytea

  @impl Ecto.Type
  @spec load(term()) :: {:ok, t()} | :error
  def load(<<bytes::bytes-size(@hash_size)>>), do: {:ok, %__MODULE__{bytes: bytes}}
  def load(_), do: :error

  @impl Ecto.Type
  @spec dump(t()) :: {:ok, binary()} | :error
  def dump(%__MODULE__{bytes: <<bytes::bytes-size(@hash_size)>>}), do: {:ok, bytes}
  def dump(_), do: :error

  @impl Ecto.Type
  @spec cast(term()) :: {:ok, t()} | :error
  def cast(<<"0x", hex_string::bytes-size(@bytes_size)>>), do: cast_hex(hex_string)
  def cast(<<hex_string::bytes-size(@bytes_size)>>), do: cast_hex(hex_string)
  def cast(<<bytes::bytes-size(@hash_size)>>), do: {:ok, %__MODULE__{bytes: bytes}}

  def cast(term) when is_integer(term) and term >= 0,
    do: {:ok, %__MODULE__{bytes: <<term::8*@hash_size>>}}

  def cast(%__MODULE__{bytes: <<_::bytes-size(@hash_size)>>} = term), do: {:ok, term}
  def cast(_term), do: :error

  defp cast_hex(hex_string) do
    case Base.decode16(hex_string, case: :mixed) do
      {:ok, bytes} ->
        {:ok, %__MODULE__{bytes: bytes}}

      _ ->
        :error
    end
  end

  def to_integer(%__MODULE__{bytes: <<n::@bits_size>>}) do
    n
  end

  def to_string(%__MODULE__{bytes: bytes}) do
    "0x" <> encode_bytes(bytes)
  end

  def to_inspect(%__MODULE__{bytes: bytes}) do
    "Address<0x#{encode_bytes(bytes)}>"
  end

  defp encode_bytes(nil), do: ""
  defp encode_bytes(<<bytes::bytes-size(@hash_size)>>) do
    Base.encode16(bytes, case: :lower)
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
