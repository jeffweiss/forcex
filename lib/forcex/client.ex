defmodule Forcex.Client do
  require Logger

  @default_endpoint "https://login.salesforce.com"

  defstruct api_version: "43.0",
            authorization_header: [],
            endpoint: @default_endpoint,
            services: %{}

  @moduledoc """
  This client delegates login to the appropriate endpoint depending on the
  type of credentials you have, and upon successful authentication keeps track
  of the authentication headers you'll need for subsequent calls.
  """

  @doc """
  Initially signs into Force.com API.

  Login credentials may be supplied. Order for locating credentials:
  1. Map supplied to `login/1`
  2. Environment variables
  3. Applications configuration

  Supplying a Map of login credentials must be in the form of

      %{
        username: "...",
        password: "...",
        security_token: "...",
        client_id: "...",
        client_secret: "...",
        endpoint: "..."
      }

  Environment variables
    - `SALESFORCE_USERNAME`
    - `SALESFORCE_PASSWORD`
    - `SALESFORCE_SECURITY_TOKEN`
    - `SALESFORCE_CLIENT_ID`
    - `SALESFORCE_CLIENT_SECRET`
    - `SALESFORCE_ENDPOINT`

  Application configuration

      config :forcex, Forcex.Client,
        username: "user@example.com",
        password: "my_super_secret_password",
        security_token: "EMAILED_FROM_SALESFORCE",
        client_id: "CONNECTED_APP_OAUTH_CLIENT_ID",
        client_secret: "CONNECTED_APP_OAUTH_CLIENT_SECRET",
        endpoint: "login.salesforce.com"

  If no `client_id` is passed login via session id will be attempted with
  `security_token`.

  Will require additional call to `locate_services/1` to identify which Force.com
  services are availabe for your deployment.

      client =
        Forcex.Client.login
        |> Forcex.Client.locate_services
  """
  def login(config \\ default_config()) do
    login(config, %__MODULE__{endpoint: config[:endpoint] || @default_endpoint})
  end

  def login(conf, starting_struct) do
    Logger.debug("conf=" <> inspect(conf))

    case conf do
      %{client_id: _} ->
        struct(__MODULE__, Forcex.Auth.OAuth.login(conf, starting_struct))

      %{security_token: _} ->
        struct(__MODULE__, Forcex.Auth.SessionId.login(conf, starting_struct))
    end
  end

  def locate_services(client) do
    services = Forcex.services(client)
    client = %{client | services: services}
    Logger.debug(inspect(client))
    client
  end

  def default_config() do
    [:username, :password, :security_token, :client_id, :client_secret, :endpoint]
    |> Enum.map(&{&1, get_val_from_env(&1)})
    |> Enum.filter(fn {_, v} -> v end)
    |> Enum.into(%{})
  end

  defp get_val_from_env(key) do
    key
    |> env_var
    |> System.get_env()
    |> case do
      nil ->
        Application.get_env(:forcex, __MODULE__, [])
        |> Keyword.get(key)

      val ->
        val
    end
  end

  defp env_var(key), do: "SALESFORCE_#{key |> to_string |> String.upcase()}"
end
