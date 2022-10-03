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

  @type forcex_response :: map | {number, any} | String.t()

  def raw_request(method, url, body, headers, options) do
    response = request!(method, url, body, headers, extra_options() ++ options)
    Logger.debug("#{__ENV__.module}.#{elem(__ENV__.function, 0)} response=" <> inspect(response))
    response
  end

  @spec extra_options :: list
  defp extra_options() do
    Application.get_env(:forcex, :request_options, [])
  end

  def process_response(%HTTPoison.Response{} = resp) do
    resp
    |> process_compressed_response()
    |> process_json_response()
    |> process_response_by_status()
  end

  defp process_compressed_response(%HTTPoison.Response{body: body, headers: headers} = resp) do
    case find_header(headers, "Content-Encoding") do
      "gzip" ->
        %{
          resp
          | body: :zlib.gunzip(body),
            headers: List.delete(headers, {"Content-Encoding", "gzip"})
        }
        |> process_compressed_response()

      "deflate" ->
        zstream = :zlib.open()
        :ok = :zlib.inflateInit(zstream, -15)
        uncompressed_data = zstream |> :zlib.inflate(body) |> Enum.join()
        :zlib.inflateEnd(zstream)
        :zlib.close(zstream)

        %{
          resp
          | body: uncompressed_data,
            headers: List.delete(headers, {"Content-Encoding", "deflate"})
        }
        |> process_compressed_response()

      _ ->
        resp
    end
  end

  defp process_json_response(%HTTPoison.Response{body: body, headers: headers} = resp) do
    case find_header(headers, "Content-Type") do
      "application/json" <> suffix ->
        %{
          resp
          | body: Poison.decode!(body, keys: :atoms),
            headers: List.delete(headers, {"Content-Type", "application/json" <> suffix})
        }

      _ ->
        resp
    end
  end

  defp process_response_by_status(%HTTPoison.Response{body: body, status_code: 200}), do: body

  defp process_response_by_status(%HTTPoison.Response{body: body, status_code: status}),
    do: {status, body}

  def process_request_headers(headers), do: headers ++ @user_agent ++ @accept ++ @accept_encoding

  defp find_header(headers, header_name) do
    Enum.find_value(
      headers,
      fn {name, value} ->
        String.downcase(name) == String.downcase(header_name) && String.downcase(value)
      end
    )
  end
end
