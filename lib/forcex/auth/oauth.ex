defmodule Forcex.Auth.OAuth do
  @moduledoc """
  Auth via OAuth
  """
  require Logger
  @behaviour Forcex.Auth

  def login(conf, starting_struct) do
    login_payload =
      conf
      |> Map.put(:password, "#{conf.password}#{conf.security_token}")
      |> Map.put(:grant_type, "password")
      |> Map.delete(:endpoint)

    "/services/oauth2/token?#{URI.encode_query(login_payload)}"
    |> Forcex.post(starting_struct)
    |> handle_login_response
    |> maybe_add_api_version(starting_struct)
  end

  defp handle_login_response(%{
         access_token: token,
         token_type: token_type,
         instance_url: endpoint
       }) do
    %{
      authorization_header: authorization_header(token, token_type),
      endpoint: endpoint
    }
  end

  defp handle_login_response({status_code, error_message}) do
    Logger.warn(
      "Cannot log into SFDC API. Please ensure you have Forcex properly configured. Got error code #{
        status_code
      } and message #{inspect(error_message)}"
    )

    %{}
  end

  defp maybe_add_api_version(client_map, %{api_version: api_version}) do
    Map.put(client_map, :api_version, api_version)
  end
  defp maybe_add_api_version(client_map, _) do
    client_map
  end

  @spec authorization_header(token :: String.t(), type :: String.t()) :: list
  defp authorization_header(nil, _), do: []

  defp authorization_header(token, type) do
    [{"Authorization", type <> " " <> token}]
  end
end
