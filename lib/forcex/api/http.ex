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

  @type method :: :get | :put | :post | :patch | :delete
  @type forcex_response :: map | {number, any} | String.t

  def raw_request(method, url, body, headers, options) do
    response = method |> request!(url, body, headers, extra_options() ++ options)
    Logger.debug("#{__ENV__.module}.#{elem(__ENV__.function, 0)} response=" <> inspect(response))
    response
  end

  @spec extra_options :: list
  defp extra_options() do
    Application.get_env(:forcex, :request_options, [])
  end

  @spec process_response(HTTPoison.Response.t) :: forcex_response
  defp process_response(%HTTPoison.Response{body: body, headers: %{"Content-Encoding" => "gzip"} = headers} = resp) do
    %{resp | body: :zlib.gunzip(body), headers: Map.drop(headers, ["Content-Encoding"])}
    |> process_response
  end
  defp process_response(%HTTPoison.Response{body: body, headers: %{"Content-Encoding" => "deflate"} = headers} = resp) do
    zstream = :zlib.open
    :ok = :zlib.inflateInit(zstream, -15)
    uncompressed_data = zstream |> :zlib.inflate(body) |> Enum.join
    :zlib.inflateEnd(zstream)
    :zlib.close(zstream)
    %{resp | body: uncompressed_data, headers: Map.drop(headers, ["Content-Encoding"])}
    |> process_response
  end
  defp process_response(%HTTPoison.Response{body: body, headers: %{"Content-Type" => "application/json" <> _} = headers} = resp) do
    %{resp | body: Poison.decode!(body, keys: :atoms), headers: Map.drop(headers, ["Content-Type"])}
    |> process_response
  end
  defp process_response(%HTTPoison.Response{body: body, status_code: 200}), do: body
  defp process_response(%HTTPoison.Response{body: body, status_code: status}), do: {status, body}

  def process_request_headers(headers), do: headers ++ @user_agent ++ @accept ++ @accept_encoding

  @spec process_headers(list({String.t, String.t})) :: map
  def process_headers(headers), do: Map.new(headers)
end
