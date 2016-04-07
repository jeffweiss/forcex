Forcex
======
[![Build Status](https://travis-ci.org/jeffweiss/forcex.svg?branch=master)](https://travis-ci.org/jeffweiss/forcex)
[![Hex.pm Version](http://img.shields.io/hexpm/v/forcex.svg?style=flat)](https://hex.pm/packages/forcex)
[![Coverage Status](https://coveralls.io/repos/github/jeffweiss/forcex/badge.svg?branch=master)](https://coveralls.io/github/jeffweiss/forcex?branch=master)

Elixir library for interacting with the Force.com REST API.

Usage
-----

Add Forcex to you dependency list
```elixir
  defp deps do
    [ {:forcex, "~> 0.2"}
    ]
  end
```

The `Forcex.Client` is configured to read login information either from
application configuration:

```elixir

config :forcex, Forcex.Client,
  username: "user@example.com",
  password: "my_super_secret_password",
  security_token: "EMAILED_FROM_SALESFORCE",
  client_id: "CONNECTED_APP_OAUTH_CLIENT_ID",
  client_secret: "CONNECTED_APP_OAUTH_CLIENT_SECRET"
```

or these environment variables:

* `SALESFORCE_USERNAME`
* `SALESFORCE_PASSWORD`
* `SALESFORCE_SECURITY_TOKEN`
* `SALESFORCE_CLIENT_ID`
* `SALESFORCE_CLIENT_SECRET`

For steps on how to create a Connected App with OAuth keys and secrets,
please see the [Force.com REST API section on Connected Apps](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/intro_defining_remote_access_applications.htm).

Currently, to be fully functional, the `Forcex.Client` must both `login` and
`locate_services`.

```elixir
client = Forcex.Client.login |> Forcex.Client.locate_services

Forcex.versions(client)

Forcex.limits(client)
```

Current State
-------------
See https://www.salesforce.com/us/developer/docs/api_rest/

 - [x] List API versions available
 - [x] Login (Username/Password/Client Key/Client Secret)
 - [ ] Login (Web Server OAuth)
 - [ ] Login (User-Agent OAuth)
 - [ ] OAuth Refresh Token
 - [x] Resources by Version
 - [x] Limits
 - [x] Describe Global
 - [x] SObject Basic Information
 - [x] SObject Describe
 - [x] SObject Get Deleted
 - [x] SObject Get Updated
 - [ ] SObject Named Layouts
 - [x] SObject Rows
 - [x] SObject Rows by External ID
 - [ ] SObject ApprovalLayouts
 - [ ] SObject CompactLayouts
 - [ ] SObject Layouts
 - [x] SObject Blob Retrieve
 - [ ] SObject Quick Actions
 - [ ] SObject Suggested Articles for Case
 - [ ] SObject User Password
 - [ ] AppMenu
 - [ ] Compact Layouts
 - [ ] FlexiPage
 - [ ] Process Approvals
 - [ ] Process Rules
 - [x] Query
 - [x] QueryAll
 - [ ] Quick Actions
 - [ ] Search
 - [ ] Search Scope and Order
 - [ ] Search Result Layouts
 - [ ] Recently Viewed Items
 - [ ] Search Suggested Article Title Matches
 - [ ] Tabs
 - [ ] Themes

License
-------
MIT License, see LICENSE
