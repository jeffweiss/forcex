defmodule Forcex do
  use GenServer
  use HTTPoison.Base
  require Logger

  @user_agent [{"User-agent", "forcex"}]
  @accept [{"Accept", "application/json"}]
  @accept_encoding [{"Accept-Encoding", "gzip,deflate"}]

  def process_request_headers(headers), do: headers ++ @user_agent ++ @accept ++ @accept_encoding

  def process_headers(headers), do: Map.new(headers)

  def process_response(%HTTPoison.Response{body: body, headers: %{"Content-Encoding" => "gzip"} = headers } = resp) do
    %{resp | body: :zlib.gunzip(body), headers: Map.drop(headers, ["Content-Encoding"])}
    |> process_response
  end
  def process_response(%HTTPoison.Response{body: body, headers: %{"Content-Encoding" => "deflate"} = headers } = resp) do
    zstream = :zlib.open
    :ok = :zlib.inflateInit(zstream, -15)
    uncompressed_data = :zlib.inflate(zstream, body) |> Enum.join
    :zlib.inflateEnd(zstream)
    :zlib.close(zstream)
    %{resp | body: uncompressed_data, headers: Map.drop(headers, ["Content-Encoding"])}
    |> process_response
  end
  def process_response(%HTTPoison.Response{body: body, headers: %{"Content-Type" => "application/json" <> _} = headers} = resp) do
    %{resp | body: JSX.decode!(body), headers: Map.drop(headers, ["Content-Type"])}
    |> process_response
  end
  def process_response(%HTTPoison.Response{body: body, status_code: 200}), do: body
  def process_response(%HTTPoison.Response{body: body, status_code: status}), do: {status, body}

  defp extra_options do
    Application.get_env(:forcex, :request_options, [])
  end

  def json_request(method, url, body, headers, options) do
    raw_request(method, url, JSX.encode!(body), headers, options)
  end

  def raw_request(method, url, body, headers, options) do
    request!(method, url, body, headers, extra_options ++ options) |> process_response
  end

  def post(path, body \\ "", client) do
    url = client.endpoint <> path
    json_request(:post, url, body, authorization_header(client), [])
  end

  def patch(path, body \\ "", client) do
    url = client.endpoint <> path
    json_request(:patch, url, body, authorization_header(client), [])
  end

  def delete(path, body \\ "", client) do
    url = client.endpoint <> path
    json_request(:delete, url, body, authorization_header(client), [])
  end

  def get(path, body \\ "", client) do
    url = client.endpoint <> path
    json_request(:get, url, body, authorization_header(client), [])
  end

  def versions(%Forcex.Client{} = client) do
    get("/services/data", client)
  end

  def services(%Forcex.Client{} = client) do
    get("/services/data/v#{client.api_version}", client)
  end

  @basic_services [
    limits: "limits",
    describe_global: "sobjects",
    quick_actions: "quickActions",
    recently_viewed_items: "recent",
    tabs: "tabs",
    theme: "theme",
  ]

  for {function, service} <- @basic_services do
    def unquote(function)(%Forcex.Client{} = client) do
      client
      |> service_endpoint(unquote(service))
      |> get(client)
    end
  end

  def describe_sobject(sobject, %Forcex.Client{} = client) do
    base = service_endpoint(client, "sobjects")

    "#{base}/#{sobject}/describe/"
    |> get(client)
  end

  def query(query, %Forcex.Client{} = client) do
    base = service_endpoint(client, "query")
    params = %{"q" => query} |> URI.encode_query

    "#{base}/?#{params}"
    |> get(client)
  end

  def query_all(query, %Forcex.Client{} = client) do
    base = service_endpoint(client, "queryAll")
    params = %{"q" => query} |> URI.encode_query

    "#{base}/?#{params}"
    |> get(client)
  end

  defp service_endpoint(%Forcex.Client{services: services}, service) do
    Map.get(services, service)
  end

  defp authorization_header(%{access_token: nil}), do: []
  defp authorization_header(%{access_token: token, token_type: type}) do
    [{"Authorization", type <> " " <> token}]
  end
end
