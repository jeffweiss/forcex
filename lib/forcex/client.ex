defmodule Forcex.Client do
  defstruct access_token: nil, api_version: "36.0", token_type: nil, endpoint: "https://login.salesforce.com"

  def login do
    c = config
    login_payload =
      c
      |> Map.put(:password, "#{c.password}#{c.security_token}")
      |> Map.put(:grant_type, "password")
    Forcex.post("/services/oauth2/token?#{URI.encode_query(login_payload)}", %__MODULE__{})
    |> handle_login_response
  end

  defp handle_login_response(%{"access_token" => token, "token_type" => token_type, "instance_url" => endpoint}) do
    %__MODULE__{access_token: token, token_type: token_type, endpoint: endpoint}
  end

  defp config do
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
