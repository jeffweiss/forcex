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

Currently, Forcex only allows for Username/Password/Client Key/Client Secret
logins. This returns a bearer token, which is also stored in the state of the
Forcex process. In addition, after login, Forcex will interrogate the Force.com
API to determine which instance we should use and what the base endpoint URIs
are for various capabilities and versions.
```elixir
{:ok, pid} = Forcex.start
Forcex.login(pid, "user@example.com", "passwordTOKEN", "ClientKey", "ClientSecret")
Forcex.query(pid, "select Id, Email from Lead where Name = 'Joe Schmoe'")
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
