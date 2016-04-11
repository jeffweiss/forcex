defmodule Mix.Tasks.Compile.Forcex do
  use Mix.Task

  @recursive false

  def run(_) do
    {:ok, _} = Application.ensure_all_started(:forcex)

    client = Forcex.Client.login

    case client do
      %{access_token: nil} -> IO.puts("Invalid configuration/credentials. Cannot generate SObjects.")
      _ -> generate_modules(client)
    end
  end

  defp generate_modules(client) do
    client = Forcex.Client.locate_services(client)

    sobjects =
      client
      |> Forcex.describe_global
      |> Map.get("sobjects")

    for sobject <- sobjects do
      sobject
      |> generate_module(client)
      |> Code.compile_quoted
    end

  end

  defp generate_module(sobject, client) do
    name = Map.get(sobject, "name")
    urls = Map.get(sobject, "urls")
    describe_url = Map.get(urls, "describe")
    sobject_url = Map.get(urls, "sobject")
    row_template_url = Map.get(urls, "rowTemplate")
    full_description = Forcex.describe_sobject(name, client)

    quote location: :keep do
      defmodule unquote(Module.concat(Forcex.SObject, name)) do
        @moduledoc """
        Dynamically generated module for `#{unquote(Map.get(full_description, "label"))}`

        ## Fields
        #{unquote(for field <- Map.get(full_description, "fields"), do: docs_for_field(field))}

        """

        @doc """
        Retrieves extended metadata for `#{unquote(name)}`

        See [SObject Describe](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_describe.htm)
        """
        def describe(client) do
          unquote(describe_url)
          |> Forcex.get(client)
        end

        @doc """
        Retrieves basic metadata for `#{unquote(name)}`

        See [SObject Basic Information](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_basic_info.htm)
        """
        def basic_info(client) do
          unquote(sobject_url)
          |> Forcex.get(client)
        end

        @doc """
        Create a new `#{unquote(name)}`


        Parameters
        * `sobject` - a map of key/value pairs

        See [SObject Basic Information](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_basic_info.htm)
        """
        def create(sobject, client) when is_map(sobject) do
          unquote(sobject_url)
          |> Forcex.post(sobject, client)
        end

        @doc """
        Update an existing `#{unquote(name)}`

        Parameters
        * `id` - 18 character SFDC identifier.
        * `changeset` - map of key/value pairs *only* of elements changing

        See [SObject Rows](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm)
        """
        def update(id, changeset, client) do
          unquote(row_template_url)
          |> String.replace("{ID}", id)
          |> Forcex.patch(changeset, client)
        end

        @doc """
        Delete an existing `#{unquote(name)}`

        Parameters
        * `id` - 18 character SFDC identifier

        See [SObject Rows](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm)
        """
        def delete(id, client) do
          unquote(row_template_url)
          |> String.replace("{ID}", id)
          |> Forcex.delete(client)
        end

        @doc """
        Retrieve an existing `#{unquote(name)}`

        Parameters
        * `id` - 18 character SFDC identifier

        See [SObject Rows](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_retrieve.htm)
        """
        def get(id, client) do
          unquote(row_template_url)
          |> String.replace("{ID}", id)
          |> Forcex.get(client)
        end

        @doc """
        Retrieve the IDs of `#{unquote(name)}`s deleted between `start_date` and `end_date`

        Parameters
        * `start_date` - `Timex.Convertable` or ISO8601 string
        * `end_date` - `Timex.Convertable` or ISO8601 string

        See [SObject Get Deleted](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_getdeleted.htm)
        """
        def deleted_between(start_date, end_date, client) when is_binary(start_date) and is_binary(end_date) do
          params = %{"start" => start_date, "end" => end_date} |> URI.encode_query
          unquote(sobject_url) <> "/deleted?#{params}"
          |> Forcex.get(client)
        end
        def deleted_between(start_date, end_date, client) do
          deleted_between(
            Timex.format!(start_date, "{ISO8601z}"),
            Timex.format!(end_date, "{ISO8601z}"),
            client)
        end

        @doc """
        Retrieve the IDs of `#{unquote(name)}`s updated between `start_date` and `end_date`

        Parameters
        * `start_date` - `Timex.Convertable` or ISO8601 string
        * `end_date` - `Timex.Convertable` or ISO8601 string

        See [SObject Get Updated](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_getupdated.htm)
        """
        def updated_between(start_date, end_date, client) when is_binary(start_date) and is_binary(end_date) do
          params = %{"start" => start_date, "end" => end_date} |> URI.encode_query
          unquote(sobject_url) <> "/updated?#{params}"
          |> Forcex.get(client)
        end
        def updated_between(start_date, end_date, client) do
          updated_between(
            Timex.format!(start_date, "{ISO}"),
            Timex.format!(end_date, "{ISO}"),
            client)
        end

        @doc """
        Retrieve a binary field in `#{unquote(name)}`

        Parameters
        * `id` - 18 character SFDC identifier
        * `field` - name of field with binary contents

        See [SObject Blob Retrieve](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_blob_retrieve.htm)
        """
        def get_blob(id, field, client) do
          unquote(row_template_url) <> "/#{field}"
          |> String.replace("{ID}", id)
          |> Forcex.get(client)
        end

        @doc """
        Retrieve `#{unquote(name)}` records based on external field `field` having value `value`

        Parameters
        * `field` - name of external field
        * `value` - value of `field` for desired records

        See [SObject Rows by External ID](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_upsert.htm)
        """
        def by_external(field, value, client) do
          unquote(sobject_url) <> "/#{field}/#{value}"
          |> Forcex.get(client)
        end
      end
      IO.puts "Generated #{unquote(Module.concat(Forcex.SObject, name))}"
    end

  end

  defp docs_for_field(%{"name" => name, "type" => type, "label" => label, "picklistValues" => values}) when type in ["picklist", "multipicklist"] do
    """
    * `#{name}` - `#{type}`, #{label}
    #{for value <- values, do: docs_for_picklist_values(value)}
    """
  end
  defp docs_for_field(%{"name" => name, "type" => type, "label" => label}) do
    "* `#{name}` - `#{type}`, #{label}\n"
  end

  defp docs_for_picklist_values(%{"value" => value, "active" => true}) do
"     * `#{value}`\n"
  end
  defp docs_for_picklist_values(_), do: ""
end
