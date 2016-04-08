defmodule Forcex.SObject do
  Application.ensure_all_started(:httpoison)

  @sobjects Forcex.Client.login |> Forcex.Client.locate_services |> Forcex.describe_global |> Map.get("sobjects")

  for sobject <- @sobjects do
    name = Map.get(sobject, "name")
    urls = Map.get(sobject, "urls")
    describe_url = Map.get(urls, "describe")
    sobject_url = Map.get(urls, "sobject")
    row_template_url = Map.get(urls, "rowTemplate")

    defmodule Module.concat(Forcex.SObject, name) do
      @moduledoc """
      Dynamically generated module for `#{name}`
      """

      @doc """
      Retrieves extended metadata for `#{name}`

      See [SObject Describe](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_describe.htm)
      """
      def describe(client) do
        unquote(describe_url)
        |> Forcex.get(client)
      end

      @doc """
      Retrieves basic metadata for `#{name}`

      See [SObject Basic Information](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_basic_info.htm)
      """
      def basic_info(client) do
        unquote(sobject_url)
        |> Forcex.get(client)
      end

      @doc """
      Create a new `#{name}`


      Parameters
      * `sobject` - a map of key/value pairs

      See [SObject Basic Information](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/resources_sobject_basic_info.htm)
      """
      def create(sobject, client) when is_map(sobject) do
        unquote(sobject_url)
        |> Forcex.post(sobject, client)
      end

      @doc """
      Update an existing `#{name}`

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
      Delete an existing `#{name}`

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
      Retrieve an existing `#{name}`

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
      Retrieve the IDs of `#{name}`s deleted between `start_date` and `end_date`

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
      Retrieve the IDs of `#{name}`s updated between `start_date` and `end_date`

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
      Retrieve a binary field in `#{name}`

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
      Retrieve `#{name}` records based on external field `field` having value `value`

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
  end
end
