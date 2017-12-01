defmodule Forcex.Client do
  defstruct access_token: nil, api_version: "41.0", token_type: nil, endpoint: "https://login.salesforce.com", services: %{}

  require Logger

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
        client_secret: "..."
      }

  Environment variables
    - `SALESFORCE_USERNAME`
    - `SALESFORCE_PASSWORD`
    - `SALESFORCE_SECURITY_TOKEN`
    - `SALESFORCE_CLIENT_ID`
    - `SALESFORCE_CLIENT_SECRET`

  Application configuration

      config :forcex, Forcex.Client,
        username: "user@example.com",
        password: "my_super_secret_password",
        security_token: "EMAILED_FROM_SALESFORCE",
        client_id: "CONNECTED_APP_OAUTH_CLIENT_ID",
        client_secret: "CONNECTED_APP_OAUTH_CLIENT_SECRET"

  Will require additional call to `locate_services/1` to identify which Force.com
  services are availabe for your deployment.

      client =
        Forcex.Client.login
        |> Forcex.Client.locate_services
  """
  def login(c \\ default_config()) do
    login(c, %__MODULE__{})
  end

  def login(conf, starting_struct) do
    login_payload =
      conf
      |> Map.put(:password, "#{conf.password}#{conf.security_token}")
      |> Map.put(:grant_type, "password")
    Forcex.post("/services/oauth2/token?#{URI.encode_query(login_payload)}", starting_struct)
    |> handle_login_response
  end

  def locate_services(client) do
    services = Forcex.services(client)
    %{client | services: services}
    |> IO.inspect
  end

  defp handle_login_response(%{access_token: token, token_type: token_type, instance_url: endpoint}) do
    %__MODULE__{access_token: token, token_type: token_type, endpoint: endpoint}
  end
  defp handle_login_response({status_code, error_message}) do
    Logger.warn "Cannot log into SFDC API. Please ensure you have Forcex properly configured. Got error code #{status_code} and message #{inspect error_message}"
    %__MODULE__{}
  end

  def default_config() do
    [:username, :password, :security_token, :client_id, :client_secret]
    |> Enum.map(&( {&1, get_val_from_env(&1)}))
    |> Enum.into(%{})
  end

  defp get_val_from_env(key) do
    key
    |> env_var
    |> System.get_env
    |> case do
      nil ->
        Application.get_env(:forcex, __MODULE__, [])
        |> Keyword.get(key)
      val -> val
    end
  end

  defp env_var(key), do: "SALESFORCE_#{key |> to_string |> String.upcase}"
end
