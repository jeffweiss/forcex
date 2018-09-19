defmodule Forcex.Auth do
  @moduledoc """
    Auth behavior
  """

  @callback login(config :: map(), struct) :: map()
end
