defmodule Forcex.Api.Http do
  @moduledoc """
  HTTP communication with Salesforce API
  """

  @behaviour Forcex.Api
  require Logger
  use HTTPoison.Base

  @user_agent [{"User-agent", "forcex"}]
  @accept [{"Accept", "application/json"}]
  @accept_encoding [{"Accept-Encoding", "gzip,deflate"}]

  @type forcex_response :: map | {number, any} | String.t

  def raw_request(method, url, body, headers, options) do
    response = method |> request!(url, body, headers, extra_options() ++ options) |> process_response()
    Logger.debug("#{__ENV__.module}.#{elem(__ENV__.function, 0)} response=" <> inspect(response))
    response
  end

  @spec extra_options :: list
  defp extra_options() do
    Application.get_env(:forcex, :request_options, [])
  end

  def process_response(%HTTPoison.Response{body: body, headers: headers} = resp) do
    cond do
      "gzip" = find_header(headers, "Content-Encoding") ->
        %{resp | body: :zlib.gunzip(body), headers: List.keydelete(headers, "Content-Encoding", 0)}
        |> process_response()

      "deflate" = find_header(headers, "Content-Encoding") ->
        zstream = :zlib.open
        :ok = :zlib.inflateInit(zstream, -15)
        uncompressed_data = zstream |> :zlib.inflate(body) |> Enum.join
        :zlib.inflateEnd(zstream)
        :zlib.close(zstream)
        %{resp | body: uncompressed_data, headers: List.delete(headers, {"Content-Encoding", "deflate"})}
        |> process_response()

      "application/json" <> suffix = find_header(headers, "Content-Type") ->
        %{resp | body: Poison.decode!(body, keys: :atoms), headers: List.delete(headers, {"Content-Type", "application/json" <> suffix})}
        |> process_response()
      true ->
        resp
    end
  end
  def process_response(%HTTPoison.Response{body: body, status_code: 200}), do: body
  def process_response(%HTTPoison.Response{body: body, status_code: status}), do: {status, body}

  def process_request_headers(headers), do: headers ++ @user_agent ++ @accept ++ @accept_encoding

  def process_headers(headers), do: Map.new(headers)

  defp find_header(headers, header_name) do
    Enum.find_value(
      headers,
      fn {name, value} ->
        name =~ ~r/#{header_name}/i && String.downcase(value)
      end
    )
  end
end
