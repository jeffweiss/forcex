defmodule Forcex.Bulk.Client do
  defstruct session_id: nil,
            api_version: "43.0",
            endpoint: "https://login.salesforce.com",
            host: nil

  require Logger

  @doc """
  Initially signs into Force.com Bulk API.

  Login credentials may be supplied. Order for locating credentials:
  1. Map supplied to `login/1`
  2. Environment variables
  3. Applications configuration

  Supplying a Map of login credentials must be in the form of

      %{
        username: "...",
        password: "...",
        security_token: "..."
      }

  Environment variables
    - `SALESFORCE_USERNAME`
    - `SALESFORCE_PASSWORD`
    - `SALESFORCE_SECURITY_TOKEN`

  Application configuration

      config :forcex, Forcex.Bulk.Client,
        username: "user@example.com",
        password: "my_super_secret_password",
        security_token: "EMAILED_FROM_SALESFORCE"

  Will require additional call to `locate_services/1` to identify which Force.com
  services are availabe for your deployment.

      client = Forcex.Bulk.Client.login
  """
  def login(c \\ default_config()) do
    login(c, %__MODULE__{})
  end

  def login(conf, starting_struct) do
    envelope = """
    <?xml version="1.0" encoding="utf-8" ?>
    <env:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:env="http://schemas.xmlsoap.org/soap/envelope/">
      <env:Body>
        <n1:login xmlns:n1="urn:partner.soap.sforce.com">
          <n1:username>#{conf.username}</n1:username>
          <n1:password>#{conf.password}#{conf.security_token}</n1:password>
        </n1:login>
      </env:Body>
    </env:Envelope>
    """

    headers = [
      {"Content-Type", "text/xml; charset=UTF-8"},
      {"SOAPAction", "login"}
    ]

    HTTPoison.post!(
      "#{starting_struct.endpoint}/services/Soap/u/#{starting_struct.api_version}",
      envelope,
      headers
    )
    |> parse_login_response
  end

  defp parse_login_response(%HTTPoison.Response{body: body, status_code: 200}) do
    {:ok,
     {'{http://schemas.xmlsoap.org/soap/envelope/}Envelope', _,
      [
        {'{http://schemas.xmlsoap.org/soap/envelope/}Body', _,
         [
           {'{urn:partner.soap.sforce.com}loginResponse', _,
            [
              {'{urn:partner.soap.sforce.com}result', _, login_parameters}
            ]}
         ]}
      ]}, _} = :erlsom.simple_form(body)

    server_url = extract_from_parameters(login_parameters, :serverUrl)
    session_id = extract_from_parameters(login_parameters, :sessionId)

    %__MODULE__{session_id: session_id, host: server_url |> URI.parse() |> Map.get(:host)}
  end

  defp extract_from_parameters(params, key) do
    compound_key = "{urn:partner.soap.sforce.com}#{key}" |> to_charlist
    {^compound_key, _, [value]} = :lists.keyfind(compound_key, 1, params)
    value |> to_string
  end

  def default_config() do
    [:username, :password, :security_token]
    |> Enum.map(&{&1, get_val_from_env(&1)})
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
