defmodule Forcex.Api do
  @moduledoc """
  Behavior for requests to Salesforce API
  """

  @type method :: :get | :put | :post | :patch | :delete
  @type response :: map | {number, any}

  @callback raw_request(method, String.t, map | String.t, list, list) :: response
end
