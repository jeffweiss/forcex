defmodule Forcex.Util do
  import Kernel, except: [to_string: 1]

  @mapping '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'

  for {char, val} <- Enum.with_index(@mapping) do
    defp char_to_num(unquote(char)), do: unquote(val)
    defp num_to_char(unquote(val)), do: unquote(char)
  end

  defp to_number(string) when is_binary(string) do
    string
    |> to_charlist
    |> Enum.map(&char_to_num/1)
    |> Enum.reduce(fn (v, acc) -> acc * 62 + v end)
  end

  defp expand(num, list) when num < 62 do
    [num|list]
  end
  defp expand(num, list) do
    mod = rem(num, 62)
    next = div(num, 62)
    expand(next, [mod|list])
  end

  defp to_string(number) when is_integer(number) do
    number
    |> expand([])
    |> Enum.map(&num_to_char/1)
    |> Kernel.to_string
  end

  def split(<<object_id::size(24), pod_id::size(16), reserved::size(8), id::size(72)>>) do
    {<<object_id::size(24)>>, <<pod_id::size(16)>>, <<reserved::size(8)>>, <<id::size(72)>>}
  end
  def split(<<object_id::size(24), pod_id::size(16), reserved::size(8), id::size(72), checksum::size(24)>>) do
    {<<object_id::size(24)>>, <<pod_id::size(16)>>, <<reserved::size(8)>>, <<id::size(72)>>, <<checksum::size(24)>>}
  end

  def unfold(min_id, max_id, desired_population_size, opts) do
    estimated_count = Keyword.get(opts, :estimate, desired_population_size)
    density = Keyword.get(opts, :density, density(min_id, max_id, estimated_count))
    unfold(min_id, max_id, round(desired_population_size / density))
  end

  def unfold(min_id, max_id, chunk_size) do
    max =
      max_id
      |> split
      |> elem(3)

    add_function = fn (sfdc_id) ->
      case split(sfdc_id) do
        {object, pod, reserved, id, _} ->
          "#{object}#{pod}#{reserved}#{id |> to_number |> Kernel.+(chunk_size) |> to_string |> String.pad_leading(9, "0")}000"
        {object, pod, reserved, id} ->
          "#{object}#{pod}#{reserved}#{id |> to_number |> Kernel.+(chunk_size) |> to_string |> String.pad_leading(9, "0")}"
      end
    end

    take_while_function = fn (sfdc_id) ->
      (sfdc_id |> split |> elem(3)) < max
    end
    list =
      min_id
      |> Stream.iterate(add_function)
      |> Stream.take_while(take_while_function)
      |> Enum.to_list
    list ++ [max_id]
  end

  def density(min, max, count) do
    [max_num, min_num] =
      [max, min]
      |> Enum.map(&split/1)
      |> Enum.map(&(elem(&1, 3)))
      |> Enum.map(&to_number/1)
    count / (max_num - min_num)
  end

end
