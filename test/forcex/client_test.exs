defmodule Forcex.ClientTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  describe "session_id based login" do
    @session_id "forcex_session_id"
    @server_url "https://forcex.my.salesforce.com/services/Soap/u/41.0/00Dd0000000cQ8L"
    @org_id "org_id"
    @response """
      <?xml version=\"1.0\" encoding=\"UTF-8\"?><soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns=\"urn:partner.soap.sforce.com\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><soapenv:Body><loginResponse><result><metadataServerUrl>#{@server_url}</metadataServerUrl><passwordExpired>false</passwordExpired><sandbox>false</sandbox><serverUrl>#{@server_url}</serverUrl><sessionId>#{@session_id}</sessionId><userId>005d0000001Jb9tAAC</userId><userInfo><accessibilityMode>false</accessibilityMode><chatterExternal>false</chatterExternal><currencySymbol>$</currencySymbol><orgAttachmentFileSizeLimit>5242880</orgAttachmentFileSizeLimit><orgDefaultCurrencyIsoCode>USD</orgDefaultCurrencyIsoCode><orgDefaultCurrencyLocale>en_US</orgDefaultCurrencyLocale><orgDisallowHtmlAttachments>false</orgDisallowHtmlAttachments><orgHasPersonAccounts>true</orgHasPersonAccounts><organizationId>#{@org_id}</organizationId><organizationMultiCurrency>false</organizationMultiCurrency><organizationName>MY-ORG</organizationName><profileId>00ed0000000Ods2AAC</profileId><roleId>00Ed0000000II8UEAW</roleId><sessionSecondsValid>7200</sessionSecondsValid><userDefaultCurrencyIsoCode xsi:nil=\"true\"/><userEmail>forcex@example.com</userEmail><userFullName>John Doe</userFullName><userId>005d0000001Jb9tAAC</userId><userLanguage>en_US</userLanguage><userLocale>en_US</userLocale><userName>forcex@example.com</userName><userTimeZone>America/New_York</userTimeZone><userType>Standard</userType><userUiSkin>Theme3</userUiSkin></userInfo></result></loginResponse></soapenv:Body></soapenv:Envelope>
"""

    test "sets the auth header and endpoint when successful" do
      config = %{
        password: "password",
        security_token: "security_token",
        username: "forcex@example.com"
      }

      Forcex.Api.MockHttp
      |> expect(:raw_request, fn :post, _, _, _, _ -> @response end)

      client = Forcex.Client.login(config)

      assert client.authorization_header == [{
        "Authorization",
        "Bearer #{@session_id}"
      }]

      assert client.endpoint == "https://forcex.my.salesforce.com/"
    end

    test "login info is HTML encoded" do
      config = %{
        password: "amper&and",
        security_token: "flash!",
        username: "<<probablynotvalid>>@example.com"
      }

      encoded_config = for {key, val} <- config, into: %{}, do: {key, HtmlEntities.encode(val)}

      expected_body = "<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n<env:Envelope xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:env=\"http://schemas.xmlsoap.org/soap/envelope/\">\n<env:Body>\n<n1:login xmlns:n1=\"urn:partner.soap.sforce.com\">\n  <n1:username>&lt;&lt;probablynotvalid&gt;&gt;@example.com</n1:username>\n  <n1:password>amper&amp;andflash!</n1:password>\n</n1:login>\n</env:Body>\n</env:Envelope>\n"

      Forcex.Api.MockHttp
      |> expect(:raw_request, fn :post, _, ^expected_body, _, _ -> @response end)

      client = Forcex.Client.login(config)
    end
  end

  describe "oauth based login" do
    test "sets the auth header and endpoint when successful" do
      org_id = "org_id"
      access_token = "access_token"

      response = %{
        access_token: access_token,
        id: "https://login.salesforce.com/id/#{org_id}/005d0000001Jb9tAAC",
        instance_url: "https://forcex.my.salesforce.com",
        issued_at: "1520973086810",
        signature: "oo7i3klbG6OjXlMFQSBzFaNYCP9pnWZ98f6Kdu/Th2Q=",
        token_type: "Bearer"
      }

      Forcex.Api.MockHttp
      |> expect(:raw_request, fn :post, _, _, _, _ -> response end)

      config = %{
        password: "password",
        security_token: "security_token",
        username: "forcex@example.com",
        client_id: "big_ol_id",
        client_secret: "sssshhhhhhhh"
      }

      client = Forcex.Client.login(config)

      assert client.authorization_header == [{
        "Authorization",
        "Bearer #{access_token}"
      }]

      assert client.endpoint == "https://forcex.my.salesforce.com"
    end
  end

  describe "locate_services" do
    test "when successful sets servies on the client" do
      response = %{
        jobs: "/services/data/v41.0/jobs",
        query: "/services/data/v41.0/query",
      }

      endpoint = "https://forcex.my.salesforce.com"
      api_version = "41.0"
      auth_header = [{"Authorization", "Bearer sometoken"}]
      services_url = endpoint <> "/services/data/v" <> api_version

      Forcex.Api.MockHttp
      |> expect(:raw_request, fn(:get, ^services_url, _, ^auth_header, _) -> response end)

      client = %Forcex.Client{
        endpoint: endpoint,
        authorization_header: auth_header,
        api_version: api_version
      }

      client = client |> Forcex.Client.locate_services
      assert client.services == response
    end
  end
end
