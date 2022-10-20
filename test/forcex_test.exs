defmodule ForcexTest do
  use ExUnit.Case

  import Mox
  setup :verify_on_exit!

  test "query" do
    api_version = "56.0"

    response = %{
      done: false,
      nextRecordsUrl: "/services/data/v#{api_version}/query/01g0W00006pQQsWQAW-2000",
      records: [
        %{
          Id: "0010W00002JBygyQAD",
          Name: "Michael Weber",
          attributes: %{
            type: "Account",
            url: "/services/data/v#{api_version}/sobjects/Account/0010W00002JBygyQAD"
          }
        },
        %{
          Id: "0010W00002JBw2mQAD",
          Name: "Erica Adams",
          attributes: %{
            type: "Account",
            url: "/services/data/v#{api_version}/sobjects/Account/0010W00002JBw2mQAD"
          }
        }
      ],
      totalSize: 5989
    }

    endpoint = "https://forcex.my.salesforce.com"
    auth_header = [{"Authorization", "Bearer sometoken"}]
    query_path = "/services/data/v#{api_version}/query"
    query = "select Id, Name from Account order by CreatedDate desc"
    query_url = "#{endpoint}#{query_path}/?#{%{"q" => query} |> URI.encode_query()}"

    Forcex.Api.MockHttp
    |> expect(:raw_request, fn :get, ^query_url, _, ^auth_header, _ -> response end)

    client = %Forcex.Client{
      endpoint: endpoint,
      authorization_header: auth_header,
      api_version: api_version,
      services: %{query: query_path}
    }

    assert Forcex.query(query, client) == response
  end
end
