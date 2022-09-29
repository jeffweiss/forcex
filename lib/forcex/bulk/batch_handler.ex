defmodule Forcex.Bulk.BatchHandler do
  @callback handle_batch_status(map, any) :: {:noreply, any}
  @callback handle_batch_created(map, any) :: {:noreply, any}
  @callback handle_batch_completed(map, any) :: {:noreply, any}
  @callback handle_batch_failed(map, any) :: {:noreply, any}
  @callback handle_batch_partial_result_ready(map, list, any) :: {:noreply, any}

  defmacro __using__(_env) do
    quote do
      @behaviour Forcex.Bulk.BatchHandler
      def handle_info({:batch_status, %{state: "Completed"} = batch}, state) do
        handle_batch_completed(batch, state)
      end

      def handle_info({:batch_status, %{state: "Failed"} = batch}, state) do
        handle_batch_failed(batch, state)
      end

      def handle_info({:batch_status, batch}, state) do
        handle_batch_status(batch, state)
      end

      def handle_info({:batch_created, batch}, state) do
        handle_batch_created(batch, state)
      end

      def handle_info({:batch_partial_result_ready, batch, result}, state) do
        handle_batch_partial_result_ready(batch, result, state)
      end
    end
  end
end
