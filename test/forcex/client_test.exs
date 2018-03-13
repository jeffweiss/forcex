defmodule Forcex.ClientTest do
  use ExUnit.Case
  import Mox

  setup :verify_on_exit!

  describe "session_id based login" do
    test "sets the auth header and endpoint when successful" do
      session_id = "forcex_session_id"
      server_url = "https://forcex.my.salesforce.com/services/Soap/u/41.0/00Dd0000000cQ8L"

      response = """
      <?xml version=\"1.0\" encoding=\"UTF-8\"?><soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" xmlns=\"urn:partner.soap.sforce.com\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"><soapenv:Body><loginResponse><result><metadataServerUrl>#{server_url}</metadataServerUrl><passwordExpired>false</passwordExpired><sandbox>false</sandbox><serverUrl>#{server_url}</serverUrl><sessionId>#{session_id}</sessionId><userId>005d0000001Jb9tAAC</userId><userInfo><accessibilityMode>false</accessibilityMode><chatterExternal>false</chatterExternal><currencySymbol>$</currencySymbol><orgAttachmentFileSizeLimit>5242880</orgAttachmentFileSizeLimit><orgDefaultCurrencyIsoCode>USD</orgDefaultCurrencyIsoCode><orgDefaultCurrencyLocale>en_US</orgDefaultCurrencyLocale><orgDisallowHtmlAttachments>false</orgDisallowHtmlAttachments><orgHasPersonAccounts>true</orgHasPersonAccounts><organizationId>00Dd0000000cQ8LEAU</organizationId><organizationMultiCurrency>false</organizationMultiCurrency><organizationName>MY-ORG</organizationName><profileId>00ed0000000Ods2AAC</profileId><roleId>00Ed0000000II8UEAW</roleId><sessionSecondsValid>7200</sessionSecondsValid><userDefaultCurrencyIsoCode xsi:nil=\"true\"/><userEmail>forcex@example.com</userEmail><userFullName>John Doe</userFullName><userId>005d0000001Jb9tAAC</userId><userLanguage>en_US</userLanguage><userLocale>en_US</userLocale><userName>forcex@example.com</userName><userTimeZone>America/New_York</userTimeZone><userType>Standard</userType><userUiSkin>Theme3</userUiSkin></userInfo></result></loginResponse></soapenv:Body></soapenv:Envelope>
"""

      Forcex.Api.MockHttp
      |> expect(:raw_request, fn :post, _, _, _, _ -> response end)

      config = %{
        password: "password",
        security_token: "security_token",
        username: "forcex@example.com"
      }

      client = Forcex.Client.login(config)

      assert client.authorization_header == [{
        "Authorization",
        "Bearer #{session_id}"
      }]

      assert client.endpoint == "https://forcex.my.salesforce.com/"
    end
  end
end
