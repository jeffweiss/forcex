defmodule Forcex.Bulk.BatchWorker do
  use GenServer
  import Forcex.Bulk.Util

  def start_link(params) do
    GenServer.start_link(__MODULE__, params)
  end

  def init({:query, opts}) do
    send(self(), :after_init)
    {:ok, opts}
  end

  def handle_info(:after_init, state) do
    client = Keyword.fetch!(state, :client)
    job = Keyword.fetch!(state, :job)
    query = Keyword.fetch!(state, :query)
    handlers = Keyword.fetch!(state,:handlers)
    interval = Keyword.get(state, :status_interval, 10000)

    batch = Forcex.Bulk.create_query_batch(query, job, client)
    notify_handlers({:batch_created, batch}, handlers)
    :timer.send_interval(interval, :fetch_status)

    {:noreply, Keyword.put(state, :batch, batch)}
  end

  def handle_info(:fetch_status, state) do
    state
    |> notify_of_partial_results
    |> notify_of_batch_status
    |> shutdown_if_needed
  end

  defp notify_of_partial_results(state) do
    client = Keyword.fetch!(state, :client)
    batch = Keyword.fetch!(state, :batch)
    handlers = Keyword.fetch!(state, :handlers)
    seen_results = Keyword.get(state, :results, [])

    results = Forcex.Bulk.fetch_batch_result_status(batch, client)
    case (results -- seen_results) do
      list when is_list(list) ->
        for result <- list do
          notify_handlers({:batch_partial_result_ready, batch, result}, handlers)
        end
      _ -> true
    end

    Keyword.put(state, :results, results)
  end

  defp notify_of_batch_status(state) do
    client = Keyword.fetch!(state, :client)
    batch = Keyword.fetch!(state, :batch)
    handlers = Keyword.fetch!(state, :handlers)

    updated_batch = Forcex.Bulk.fetch_batch_status(batch, client)

    notify_handlers({:batch_status, updated_batch}, handlers)

    Keyword.put(state, :batch, updated_batch)
  end

  defp shutdown_if_needed(state) do
    state
    |> Keyword.fetch!(:batch)
    |> case do
      %{"state" => "Completed"} -> {:stop, :normal, state}
      _ -> {:noreply, state}
    end
  end

end
