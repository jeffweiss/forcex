defmodule Forcex.Auth do
  @moduledoc """
    Auth behavior
  """

  @callback login(config :: Map.t()) :: Map.t()
end
