defmodule Forcex.Bulk.JobHandler do
  @callback handle_job_created(map, any) :: {:noreply, any}
  @callback handle_job_closed(map, any) :: {:noreply, any}
  @callback handle_job_all_batches_complete(map, any) :: {:noreply, any}
  @callback handle_job_status(map, any) :: {:noreply, any}

  defmacro __using__(_env) do
    quote do
      @behaviour Forcex.Bulk.JobHandler
      def handle_info({:job_created, job}, state) do
        handle_job_created(job, state)
      end

      def handle_info({:job_status, %{state: "Closed"} = job}, state) do
        handle_job_closed(job, state)
      end

      def handle_info(
            {:job_status, %{numberBatchesCompleted: num, numberBatchesTotal: num} = job},
            state
          ) do
        handle_job_all_batches_complete(job, state)
      end

      def handle_info({:job_status, job}, state) do
        handle_job_status(job, state)
      end

      def handle_info({:job_closed, job}, state) do
        handle_job_closed(job, state)
      end
    end
  end
end
