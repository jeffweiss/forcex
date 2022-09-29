defmodule Forcex.Bulk.Util do
  @moduledoc false

  def notify_handlers(msg, handlers) do
    for handler <- handlers do
      spawn(fn -> send(handler, msg) end)
    end
  end
end
