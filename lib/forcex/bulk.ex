defmodule Forcex.Bulk do
  @moduledoc """
  Force.com Bulk Job interface
  """

  use HTTPoison.Base
  require Logger

  @user_agent [{"User-agent", "forcex"}]
  @accept [{"Accept", "application/json"}]
  @accept_encoding [{"Accept-Encoding", "gzip"}]
  @content_type [{"Content-Type", "application/json"}]
  #  @pk_chunking [{"Sforce-Enable-PKChunking", "chunkSize=50000"}]

  @type id :: binary
  @type job :: map
  @type batch :: map

  def process_request_headers(headers),
    do: headers ++ @user_agent ++ @accept ++ @accept_encoding ++ @content_type

  def process_headers(headers), do: Map.new(headers)

  def process_response(%HTTPoison.Response{body: body, headers: headers} = resp) do
    cond do
      "gzip" = find_header(headers, "Content-Encoding") ->
        %{
          resp
          | body: :zlib.gunzip(body),
            headers: List.delete(headers, {"Content-Encoding", "gzip"})
        }
        |> process_response()

      "application/json" <> suffix = find_header(headers, "Content-Type") ->
        %{
          resp
          | body: Jason.decode!(body),
            headers: List.delete(headers, {"Content-Type", "application/json" <> suffix})
        }
        |> process_response()

      true ->
        resp
    end
  end

  def process_response(%HTTPoison.Response{body: body, status_code: status})
      when status < 300 and status >= 200,
      do: body

  def process_response(%HTTPoison.Response{body: body, status_code: status}), do: {status, body}

  defp extra_options() do
    Application.get_env(:forcex, :request_options, [])
  end

  defp authorization_header(%{session_id: nil}), do: []

  defp authorization_header(%{session_id: session}) do
    [{"X-SFDC-Session", session}]
  end

  def json_request(method, url, body, headers, options) do
    raw_request(method, url, JSX.encode!(body), headers, options)
  end

  def raw_request(method, url, body, headers, options) do
    request!(method, url, body, headers, extra_options() ++ options) |> process_response
  end

  def client_get(path, headers \\ [], client) do
    url = "https://#{client.host}/services/async/#{client.api_version}" <> path
    raw_request(:get, url, "", headers ++ authorization_header(client), [])
  end

  def client_post(path, body \\ "", client) do
    url = "https://#{client.host}/services/async/#{client.api_version}" <> path
    json_request(:post, url, body, authorization_header(client), [])
  end

  @spec create_query_job(binary, map) :: job
  def create_query_job(sobject, client) do
    payload = %{
      "operation" => "query",
      "object" => sobject,
      "concurrencyMode" => "Parallel",
      "contentType" => "JSON"
    }

    client_post("/job", payload, client)
  end

  @spec close_job(job | id, map) :: job
  def close_job(job, client) when is_map(job) do
    close_job(job.id, client)
  end

  def close_job(id, client) when is_binary(id) do
    client_post("/job/#{id}", %{"state" => "Closed"}, client)
  end

  @spec fetch_job_status(job | id, map) :: job
  def fetch_job_status(job, client) when is_map(job), do: fetch_job_status(job.id, client)

  def fetch_job_status(id, client) when is_binary(id) do
    client_get("/job/#{id}", client)
  end

  @spec create_query_batch(String.t(), job | id, map) :: job
  def create_query_batch(soql, job, client) when is_map(job),
    do: create_query_batch(soql, job.id, client)

  def create_query_batch(soql, job_id, client) when is_binary(soql) and is_binary(job_id) do
    url = "https://#{client.host}/services/async/#{client.api_version}" <> "/job/#{job_id}/batch"
    raw_request(:post, url, soql, authorization_header(client), [])
  end

  @spec fetch_batch_status(batch, map) :: batch
  def fetch_batch_status(batch, client) when is_map(batch) do
    fetch_batch_status(batch.id, batch.jobId, client)
  end

  @spec fetch_batch_status(id, job | id, map) :: batch
  def fetch_batch_status(id, job, client) when is_binary(id) and is_map(job) do
    fetch_batch_status(id, job.id, client)
  end

  def fetch_batch_status(id, job_id, client) when is_binary(id) and is_binary(job_id) do
    client_get("/job/#{job_id}/batch/#{id}", client)
  end

  @spec fetch_batch_result_status(batch, map) :: list(String.t())
  def fetch_batch_result_status(batch, client) when is_map(batch) do
    fetch_batch_result_status(batch.id, batch.jobId, client)
  end

  @spec fetch_batch_result_status(id, id, map) :: list(String.t())
  def fetch_batch_result_status(batch_id, job_id, client)
      when is_binary(batch_id) and is_binary(job_id) do
    client_get("/job/#{job_id}/batch/#{batch_id}/result", client)
  end

  @spec fetch_results(id, batch, map) :: list(map)
  def fetch_results(id, batch, client) when is_binary(id) and is_map(batch) do
    fetch_results(id, batch.id, batch.jobId, client)
  end

  @spec fetch_results(id, id, id, map) :: list(map)
  def fetch_results(id, batch_id, job_id, client)
      when is_binary(id) and is_binary(batch_id) and is_binary(job_id) do
    client_get("/job/#{job_id}/batch/#{batch_id}/result/#{id}", client)
  end

  defp find_header(headers, header_name) do
    Enum.find_value(
      headers,
      fn {name, value} ->
        name =~ ~r/#{header_name}/i && String.downcase(value)
      end
    )
  end
end
