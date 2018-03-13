defmodule Forcex.Auth do
  @moduledoc """
    Auth behavior
  """

  @callback login(config :: Map.t(), struct) :: Map.t()
end
