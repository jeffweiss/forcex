defmodule Forcex do
  use HTTPoison.Base

  def api_host do
    System.get_env("FORCEX_API_HOST") || "na1.salesforce.com"
  end

  def api_version do
    System.get_env("FORCEX_API_VERSION") || most_recent_version
  end

  def username do
    System.get_env("FORCEX_USERNAME") || ""
  end

  def password do
    System.get_env("FORCEX_PASSWORD") || ""
  end

  def client_id do
    System.get_env("FORCEX_CLIENT_KEY") || ""
  end

  def client_secret do
    System.get_env("FORCEX_CLIENT_SECRET") || ""
  end

  def login(user \\ username, pass \\ password, clientid \\ client_id, clientsecret \\ client_secret) do
    body = %{"grant_type" => "password",
             "client_id" => clientid,
             "client_secret" => clientsecret,
             "username" => user,
             "password" => pass}
    |> URI.encode_query
    |> IO.inspect
    post!("https://login.salesforce.com/services/oauth2/token?" <> body, "")
  end

  def process_response_body(body) do
    body
    |> JSEX.decode!
  end

  def version_list do
    "https://" <> api_host <> "/services/data"
    |> get!
    |> Map.get(:body)
  end

  def most_recent_version do
    version_list
    |> List.last
    |> Map.get("version")
  end

  def service_endpoint_for_version(version) do
    version_list
    |> Enum.filter( fn(x) -> Map.get(x, "version") == version end )
    |> List.first
    |> Map.get("url")
  end
end
