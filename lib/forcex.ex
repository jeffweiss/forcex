defmodule Forcex do
  use GenServer

  ###
  # Public API
  ###

  def start(initial_state \\ %{}) do
    HTTPoison.start
    GenServer.start __MODULE__, initial_state
  end

  def init(initial_state) do
    state = %{:instance_url  => "https://login.salesforce.com",
              :api_version   => "32.0",
              :username      => System.get_env("FORCEX_USERNAME"),
              :password      => System.get_env("FORCEX_PASSWORD"),
              :client_id     => System.get_env("FORCEX_CLIENT_ID"),
              :client_secret => System.get_env("FORCEX_CLIENT_SECRET")
            }
            |> Map.merge(initial_state)
    {:ok, state}
  end

  def login(pid, username, password, client_id, client_secret) do
    GenServer.call pid, {:login, username, password, client_id, client_secret}
  end

  def versions(pid) do
    GenServer.call pid, :versions
  end

  def version_endpoint(pid, version) do
    GenServer.call pid, {:version_endpoint, version}
  end

  def available_resources(pid) do
    GenServer.call pid, :available_resources
  end

  def limits(pid) do
    GenServer.call pid, :limits
  end

  ###
  # Private API
  ###

  def handle_call({:login, _, _, _, _}, _from, state = %{access_token: token, token_type: _}) do
    {:reply, token, state}
  end

  def handle_call({:login, username, password, client_id, client_secret}, _from, state) do
    params = %{"grant_type"    => "password",
               "client_id"     => client_id,
               "client_secret" => client_secret,
               "username"      => username,
               "password"      => password}
             |> URI.encode_query
    case HTTPoison.post(state[:instance_url] <> "/services/oauth2/token?" <> params, "") do
      {:ok, %HTTPoison.Response{status_code: 200, body: json}} ->
        body = json |> JSEX.decode!
        override = %{:access_token => body["access_token"],
          :instance_url => body["instance_url"],
          :token_type   => body["token_type"],
          :service_endpoint => version_endpoint_on_instance(body["instance_url"], state.api_version)}

        new_state = Map.merge(state, override)

        {:reply, body["access_token"], new_state}
      {:ok, %HTTPoison.Response{status_code: 400, body: json}} ->
        body = json |> JSEX.decode!
        {:error, body, state}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason, state}
    end
  end

  def handle_call(:versions, _from, state) do
    {:reply, versions_on_instance(state.instance_url), state}
  end

  def handle_call({:version_endpoint, version}, _from, state) do
    {:reply, version_endpoint_on_instance(state.instance_url, version), state}
  end

  def handle_call(:available_resources, _from, state = %{instance_url: url, service_endpoint: endpoint, access_token: token, token_type: token_type}) do
    resources = authenticated_get(url, endpoint, "", token, token_type)
    {:reply, resources, state}
  end

  def handle_call(:limits, _from, state = %{instance_url: url, service_endpoint: endpoint, access_token: token, token_type: token_type}) do
    limits = authenticated_get(url, endpoint, "/limits", token, token_type)
    {:reply, limits, state}
  end

  ###
  # Helper functions
  ###

  defp versions_on_instance(instance_url) do
    instance_url <> "/services/data"
    |> HTTPoison.get!
    |> Map.get(:body)
    |> JSEX.decode!
  end

  defp version_endpoint_on_instance(instance, version) do
    instance
    |> versions_on_instance
    |> Enum.filter( fn(x) -> Map.get(x, "version") == version end)
    |> List.first
    |> Map.get("url")
  end

  defp authenticated_get(url, version_endpoint, endpoint, token, token_type) do
    url <> version_endpoint <> endpoint
    |> HTTPoison.get!(%{"Authorization" => (token_type <> " " <> token)})
    |> Map.get(:body)
    |> JSEX.decode!
  end

end
