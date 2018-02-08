defmodule Forcex do
  use HTTPoison.Base
  require Logger

  @user_agent [{"User-agent", "forcex"}]
  @accept [{"Accept", "application/json"}]
  @accept_encoding [{"Accept-Encoding", "gzip,deflate"}]
  @content_type [{"Content-Type", "application/json; charset=utf-8"}]

  @type client :: map
  @type response :: map | {number, any}
  @type method :: :get | :put | :post | :patch | :delete

  @spec process_request_headers(list({String.t, String.t})) :: list({String.t, String.t})
  def process_request_headers(headers), do: headers ++ @user_agent ++ @accept ++ @accept_encoding ++ @content_type

  @spec process_headers(list({String.t, String.t})) :: map
  def process_headers(headers), do: Map.new(headers)

  @spec process_response(HTTPoison.Response.t) :: response
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
    %{resp | body: Poison.decode!(body, keys: :atoms), headers: Map.drop(headers, ["Content-Type"])}
    |> process_response
  end
  def process_response(%HTTPoison.Response{body: body, status_code: status}) when status in [200, 201, 204], do: body
  def process_response(%HTTPoison.Response{body: body, status_code: status}), do: {status, body}

  @spec extra_options :: list
  defp extra_options() do
    Application.get_env(:forcex, :request_options, [])
  end

  @spec json_request(method, String.t, map | String.t, list, list) :: response
  def json_request(method, url, body, headers, options) do
    raw_request(method, url, Poison.encode!(body), headers, options)
  end

  @spec raw_request(method, String.t, map | String.t, list, list) :: response
  def raw_request(method, url, body, headers, options) do
    request!(method, url, body, headers, extra_options() ++ options) |> process_response
  end

  @spec post(String.t, map | String.t, client) :: response
  def post(path, body \\ "", client) do
    url = client.endpoint <> path
    json_request(:post, url, body, authorization_header(client), [])
  end

  @spec patch(String.t, String.t, client) :: response
  def patch(path, body \\ "", client) do
    url = client.endpoint <> path
    json_request(:patch, url, body, authorization_header(client), [])
  end

  @spec delete(String.t, client) :: response
  def delete(path, client) do
    url = client.endpoint <> path
    raw_request(:delete, url, "", authorization_header(client), [])
  end

  @spec get(String.t, map | String.t, list, client) :: response
  def get(path, body \\ "", headers \\ [], client) do
    url = client.endpoint <> path
    json_request(:get, url, body, headers ++ authorization_header(client), [])
  end

  @spec versions(client) :: response
  def versions(%Forcex.Client{} = client) do
    get("/services/data", client)
  end

  @spec services(client) :: response
  def services(%Forcex.Client{} = client) do
    get("/services/data/v#{client.api_version}", client)
  end

  @basic_services [
    limits: :limits,
    describe_global: :sobjects,
    quick_actions: :quickActions,
    recently_viewed_items: :recent,
    tabs: :tabs,
    theme: :theme,
  ]

  for {function, service} <- @basic_services do
    @spec unquote(function)(client) :: response
    def unquote(function)(%Forcex.Client{} = client) do
      client
      |> service_endpoint(unquote(service))
      |> get(client)
    end
  end

  @spec describe_sobject(String.t, client) :: response
  def describe_sobject(sobject, %Forcex.Client{} = client) do
    base = service_endpoint(client, :sobjects)

    "#{base}/#{sobject}/describe/"
    |> get(client)
  end

  def attachment_body(binary_path, %Forcex.Client{} = client) do
    base = service_endpoint(client, "sobjects")

    "#{base}/Attachment/#{binary_path}/Body"
    |> get(client)
  end

  @spec metadata_changes_since(String.t, String.t, client) :: response
  def metadata_changes_since(sobject, since, client) do
    base = service_endpoint(client, :sobjects)

    "#{base}/#{sobject}/describe/"
    |> get("", [{"If-Modified-Since", since}], client)
  end

  @spec query(String.t, client) :: response
  def query(query, %Forcex.Client{} = client) do
    base = service_endpoint(client, :query)
    params = %{"q" => query} |> URI.encode_query

    "#{base}/?#{params}"
    |> get(client)
  end

  @spec query_all(String.t, client) :: response
  def query_all(query, %Forcex.Client{} = client) do
    base = service_endpoint(client, :queryAll)
    params = %{"q" => query} |> URI.encode_query

    "#{base}/?#{params}"
    |> get(client)
  end

  @spec service_endpoint(client, String.t) :: String.t
  defp service_endpoint(%Forcex.Client{services: services}, service) do
    Map.get(services, service)
  end

  @spec authorization_header(client) :: list
  defp authorization_header(%{access_token: nil}), do: []
  defp authorization_header(%{access_token: token, token_type: type}) do
    [{"Authorization", type <> " " <> token}]
  end
end
