defmodule Forcex do
  use GenServer
  require Logger

  ###
  # Public API
  ###

  def start(initial_state \\ %{}) do
    HTTPoison.start
    GenServer.start __MODULE__, initial_state
  end

  def init(initial_state) do
    state = %{:instance_url  => "https://login.salesforce.com",
              :api_version   => "32.0",
              :username      => System.get_env("FORCEX_USERNAME"),
              :password      => System.get_env("FORCEX_PASSWORD"),
              :client_id     => System.get_env("FORCEX_CLIENT_ID"),
              :client_secret => System.get_env("FORCEX_CLIENT_SECRET")
            }
            |> Map.merge(initial_state)
    {:ok, state}
  end

  def login(pid, username, password, client_id, client_secret) do
    GenServer.call pid, {:login, username, password, client_id, client_secret}
  end

  def versions(pid) do
    GenServer.call pid, :versions
  end

  def version_endpoint(pid, version) do
    GenServer.call pid, {:version_endpoint, version}
  end

  def available_resources(pid) do
    GenServer.call pid, :available_resources
  end

  def limits(pid) do
    GenServer.call pid, :limits
  end

  def available_objects(pid) do
    GenServer.call pid, :available_objects
  end

  def metadata(pid, object) do
    GenServer.call pid, {:metadata, object}
  end

  def describe(pid, object) do
    GenServer.call pid, {:describe, object}
  end

  def query(pid, query, options \\ %{page_until_complete: false}, timeout \\ 5000) do
    GenServer.call pid, {:query, query, options}, timeout
  end

  def query_all(pid, query, options \\ %{page_until_complete: false}, timeout \\ 5000) do
    GenServer.call pid, {:query_all, query, options}, timeout
  end

  def next_query_results(pid, query_id) do
    GenServer.call pid, {:next_query_results, query_id}
  end

  def explain_query(pid, query) do
    GenServer.call pid, {:explain_query, query}
  end

  def read_binary_field(pid, sobject, id, field) do
    GenServer.call pid, {:read_binary_field, sobject, id, field}
  end

  def read_object(pid, sobject, id) do
    GenServer.call pid, {:read_object, sobject, id}
  end

  def read_objects_by_field_value(pid, sobject, field, value) do
    GenServer.call pid, {:read_objects_by_field_value, sobject, field, value}
  end

  def updated_object_ids_between(pid, sobject, startdate, enddate) do
    GenServer.call pid, {:updated_between, sobject, startdate, enddate}
  end

  def deleted_object_ids_between(pid, sobject, startdate, enddate) do
    GenServer.call pid, {:deleted_between, sobject, startdate, enddate}
  end

  ###
  # Private API
  ###

  def handle_call({:login, _, _, _, _}, _from, state = %{access_token: token, token_type: _}) do
    {:reply, token, state}
  end

  def handle_call({:login, username, password, client_id, client_secret}, _from, state) do
    params = %{"grant_type"    => "password",
               "client_id"     => client_id,
               "client_secret" => client_secret,
               "username"      => username,
               "password"      => password}
             |> URI.encode_query
    case HTTPoison.post(state[:instance_url] <> "/services/oauth2/token?" <> params, "") do
      {:ok, %HTTPoison.Response{status_code: 200, body: json}} ->
        body = json |> JSX.decode!
        service_endpoint = version_endpoint_on_instance(body["instance_url"], state.api_version)
        override = %{:access_token => body["access_token"],
          :instance_url => body["instance_url"],
          :token_type   => body["token_type"],
          :service_endpoint => service_endpoint,
          :object_endpoint_hash => available_resources(body["instance_url"], service_endpoint, body["access_token"], body["token_type"])
        }

        new_state = Map.merge(state, override)

        {:reply, body["access_token"], new_state}
      {:ok, %HTTPoison.Response{status_code: 400, body: json}} ->
        body = json |> JSX.decode!
        {:error, body, state}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason, state}
    end
  end

  def handle_call(:versions, _from, state) do
    {:reply, versions_on_instance(state.instance_url), state}
  end

  def handle_call({:version_endpoint, version}, _from, state) do
    {:reply, version_endpoint_on_instance(state.instance_url, version), state}
  end

  def handle_call(:available_resources, _from, state = %{instance_url: url, service_endpoint: endpoint, access_token: token, token_type: token_type}) do
    resources = available_resources(url, endpoint, token, token_type)
    {:reply, resources, state}
  end
  def handle_call(:available_resources, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call(:limits, _from, state = %{access_token: _token, token_type: _token_type}) do
    limits = authenticated_get("limits", "", state)
    {:reply, limits, state}
  end
  def handle_call(:limits, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call(:available_objects, _from, state = %{access_token: _token, token_type: _token_type}) do
    objects = authenticated_get("sobjects", "", state)
    {:reply, objects, state}
  end
  def handle_call(:available_objects, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call({:metadata, object}, _from, state = %{access_token: _token, token_type: _token_type}) do
    metadata = authenticated_get("sobjects", object, state)
    {:reply, metadata, state}
  end
  def handle_call({:metadata, _}, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call({:describe, object}, _from, state = %{access_token: _token, token_type: _token_type}) do
    description = authenticated_get("sobjects", object <> "/describe", state)
    {:reply, description, state}
  end
  def handle_call({:describe, _}, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call({:query, query, opts = %{page_until_complete: false}}, _from, state = %{access_token: _token, token_type: _token_type}) do
    params = %{"q" => query} |> URI.encode_query
    if Map.get(opts, :warn_on_table_scan, false) == true, do: warn_on_table_scan({:query, query}, state)
    results = authenticated_get("query", "?" <> params, state)
    {:reply, results, state}
  end
  def handle_call({:query, query, opts = %{page_until_complete: true}}, _from, state = %{instance_url: url, access_token: token, token_type: token_type}) do
    params = %{"q" => query} |> URI.encode_query
    if Map.get(opts, :warn_on_table_scan, false) == true, do: warn_on_table_scan({:query, query}, state)
    results = authenticated_get("query", "?" <> params, state)
    all_results = page_until_complete([], results, url, token, token_type)

    {:reply, all_results, state}
  end
  def handle_call({:query, _, _}, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call({:query_all, query, opts = %{page_until_complete: false}}, _from, state = %{access_token: _token, token_type: _token_type}) do
    params = %{"q" => query} |> URI.encode_query
    if Map.get(opts, :warn_on_table_scan, false) == true, do: warn_on_table_scan({:queryAll, query}, state)
    if opts.warn_on_table_scan == true, do: warn_on_table_scan({:queryAll, query}, state)
    results = authenticated_get("queryAll", "?" <> params, state)
    {:reply, results, state}
  end
  def handle_call({:query_all, query, opts = %{page_until_complete: true}}, _from, state = %{instance_url: url, access_token: token, token_type: token_type}) do
    params = %{"q" => query} |> URI.encode_query
    if Map.get(opts, :warn_on_table_scan, false) == true, do: warn_on_table_scan({:queryAll, query}, state)
    results = authenticated_get("queryAll", "?" <> params, state)
    all_results = page_until_complete([], results, url, token, token_type)

    {:reply, all_results, state}
  end
  def handle_call({:query_all, _, _}, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call({:next_query_results, query = <<"/services"::utf8, _::binary>>}, _from, state = %{instance_url: url, service_endpoint: _, access_token: token, token_type: token_type}) do
    results = authenticated_get(url <> query, {token, token_type})
    {:reply, results, state}
  end
  def handle_call({:next_query_results, query}, _from, state = %{access_token: _token, token_type: _token_type}) do
    results = authenticated_get("query", query, state)
    {:reply, results, state}
  end
  def handle_call({:next_query_results, _}, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call({:explain_query, query}, _from, state = %{access_token: _token, token_type: _token_type}) do
    params = %{"explain" => query} |> URI.encode_query
    results = authenticated_get("query", "?" <> params, state)
    {:reply, results, state}
  end
  def handle_call({:explain_query, _, _}, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call({:read_binary_field, sobject, id, field}, _from, state = %{access_token: _token, token_type: _token_type}) do
    results = authenticated_get("sobjects", sobject <> "/" <> id <> "/" <> field, state)
    {:reply, results, state}
  end
  def handle_call({:read_binary_field, _, _, _}, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call({:read_object, sobject, id}, _from, state = %{access_token: _token, token_type: _token_type}) do
    results = authenticated_get("sobjects", sobject <> "/" <> id, state)
    {:reply, results, state}
  end
  def handle_call({:read_object, _, _}, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call({:read_objects_by_field_value, sobject, field, value}, _from, state = %{access_token: _token, token_type: _token_type}) do
    results = authenticated_get("sobjects", sobject <> "/#{field}/#{URI.encode(value)}", state)
    {:reply, results, state}
  end
  def handle_call({:read_objects_by_field_value, _, _}, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call({:updated_between, sobject, startdate, enddate}, _from, state = %{access_token: _token, token_type: _token_type}) do
    results = objects_in_range("updated", sobject, startdate, enddate, state)
    {:reply, results, state}
  end
  def handle_call({:updated_between, _, _, _}, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  def handle_call({:deleted_between, sobject, startdate, enddate}, _from, state = %{access_token: _token, token_type: _token_type}) do
    results = objects_in_range("deleted", sobject, startdate, enddate, state)
    {:reply, results, state}
  end
  def handle_call({:deleted_between, _, _, _}, _from, state), do: {:reply, {:error, :not_logged_in}, state}

  ###
  # Helper functions
  ###

  defp versions_on_instance(instance_url) do
    instance_url <> "/services/data"
    |> HTTPoison.get!
    |> Map.get(:body)
    |> JSX.decode!
  end

  defp version_endpoint_on_instance(instance, version) do
    instance
    |> versions_on_instance
    |> Enum.filter( fn(x) -> Map.get(x, "version") == version end)
    |> List.first
    |> Map.get("url")
  end

  defp available_resources(url, endpoint, token, token_type) do
    authenticated_get(url <> endpoint, {token, token_type})
  end

  defp authenticated_get(url = <<"http"::utf8, _::binary>>, {token, token_type}) do
    url
    |> HTTPoison.get!(%{"Authorization" => (token_type <> " " <> token)})
    |> parse_payload
  end
  defp authenticated_get(object, params, state = %{instance_url: url, access_token: token, token_type: token_type}) do
    endpoint = endpoint_for_object(object, state)
    case endpoint do
      <<"/"::utf8, _::binary>> -> url <> endpoint <> "/" <> params
      _ -> url <> "/" <> params
    end
    |> authenticated_get({token, token_type})
  end

  defp parse_payload(%{body: body, headers: %{"Content-Type" => <<"application/json"::utf8, _::binary>>}}) do
    body
    |> JSX.decode!
  end
  defp parse_payload(%{body: body}), do: body

  defp page_until_complete(record_accumulator, results = %{"done" => true}, _, _, _) do
    %{results | "records" => record_accumulator ++ results["records"]}
  end
  defp page_until_complete(record_accumulator, prev_results, url, token, token_type) do
    next_url = prev_results["nextRecordsUrl"]
    results = authenticated_get(url <> next_url, {token, token_type})
    record_accumulator ++ prev_results["records"]
    |> page_until_complete(results, url, token, token_type)
  end

  defp endpoint_for_object(object, %{object_endpoint_hash: hash, service_endpoint: endpoint}) do
    case Map.get(hash, object) do
      nil -> manually_construct_endpoint(object, endpoint)
      result -> result
    end
  end

  defp manually_construct_endpoint(object, endpoint) do
    Logger.debug "object hash doesn't contain: " <> object <> ". Constructing manually."
    endpoint <> "/" <> object
  end

  defp warn_on_table_scan({queryType, query}, state) do
    params = %{"explain" => query} |> URI.encode_query
    planType = queryType
      |> Atom.to_string
      |> authenticated_get("?" <> params, state)
      |> Map.get("plans")
      |> List.first
      |> Map.get("leadingOperationType")
    if planType == "TableScan", do: Logger.warn("Query will result in table scan: " <> query)
    query
  end

  def objects_in_range(type, sobject, startdate, enddate, state) do
    params = %{:start => startdate |> Timex.Date.from |> Timex.DateFormat.format!("{ISO}"),
               :end   => enddate   |> Timex.Date.from |> Timex.DateFormat.format!("{ISO}") }
             |> URI.encode_query
    authenticated_get("sobjects", sobject <> "/#{type}/?" <> params, state)
  end

end
