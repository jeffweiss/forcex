defmodule Forcex.Bulk.JobWorker do
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
    sobject = Keyword.fetch!(state, :sobject)
    handlers = Keyword.get(state, :handlers, [])
    interval = Keyword.get(state, :status_interval, 10000)

    job = Forcex.Bulk.create_query_job(sobject, client)
    notify_handlers({:job_created, job}, handlers)
    :timer.send_interval(interval, :fetch_status)

    {:noreply, Keyword.put(state, :job, job)}
  end

  def handle_info(:fetch_status, state) do
    client = Keyword.fetch!(state, :client)
    job = Keyword.fetch!(state, :job)
    handlers = Keyword.get(state, :handlers, [])

    updated_job = Forcex.Bulk.fetch_job_status(job, client)

    notify_handlers({:job_status, updated_job}, handlers)

    {:noreply, Keyword.put(state, :job, updated_job)}
  end

  def handle_info(:close_job, state) do
    client = Keyword.fetch!(state, :client)
    job = Keyword.fetch!(state, :job)
    handlers = Keyword.get(state, :handlers, [])
    closed_job = %{state: "Closed"} = Forcex.Bulk.close_job(job, client)

    notify_handlers({:job_closed, closed_job}, handlers)
    {:stop, :normal, Keyword.put(state, :job, closed_job)}
  end
end
