defmodule Forcex.Client do
  defstruct auth: nil, endpoint: "https://login.salesforce.com"

  def new do
    [:username, :password, :security_token, :client_key, :client_secret]
    |> Enum.map(&( {&1, get_val_from_env(&1)}))
    |> Enum.into(%{})
    |> new
  end
  def new(auth), do: %__MODULE__{auth: auth}
  def new(auth, endpoint) do
    endpoint = if String.ends_with?("/"), do: endpoint, else: endpoint <> "/"
    %__MODULE__{auth: auth, endpoint: endpoint}
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
