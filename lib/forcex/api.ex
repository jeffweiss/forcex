defmodule Forcex.Api do
  @moduledoc """
  Behavior for requests to Salesforce API
  """

  @type method :: :get | :put | :post | :patch | :delete
  @type forcex_response :: map | {number, any} | String.t()

  @callback raw_request(method, String.t(), map | String.t(), list, list) :: forcex_response
end
