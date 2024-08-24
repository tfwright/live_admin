<!-- This README was generated with docout (https://github.com/tfwright/docout). Edits should be made to the formatter instead of this file, other changes will be overridden on compile. -->

# LiveAdmin

[![hex package](https://img.shields.io/hexpm/v/live_admin.svg)](https://hex.pm/packages/live_admin)
[![CI status](https://github.com/tfwright/live_admin/workflows/CI/badge.svg)](https://github.com/tfwright/live_admin/actions)

An admin UI for Phoenix applications built on [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view) and [Ecto](https://github.com/elixir-ecto/ecto/).

Significant features:

* Minimal required configuration
* First class support for multi tenant applications via Ecto's `prefix` option
* Overridable views and API
* Easily add custom actions at the schema and record level
* Ability to edit (nested) embedded schemas
* i18n via [Gettext](https://github.com/elixir-gettext/gettext)

## (Required) Installation

One of the main design goals of LiveAdmin is to require as little config as possible.
It should be useable out of the box for most internal admin use cases using defaults.
If you are already running LiveView in your application, it should only take a few minutes to expose a UI for your resources.

First, ensure your Phoenix app has been configured to use [LiveView](https://hexdocs.pm/phoenix_live_view/installation.html).

Add to your app's `deps`:

```elixir
{:live_admin, "~> 0.12.1"}
```

Configure a module to act as a LiveAdmin resource:

```elixir
defmodule MyApp.Admin.Foo do
  use LiveAdmin.Resource, schema: MyApp.Foo
end
```

*Note: if your module is an Ecto schema you can omit the `schema` option.*

In your Phoenix router, inside a scope configured to run LiveView (`:browser` if you followed the default installation), add the resource to a LiveAdmin instance:

```elixir
import LiveAdmin.Router

...

scope "/" do
  pipe_through: :browser

  live_admin "/admin" do
    admin_resource "/foos", MyApp.Admin.Foo
  end
end
```

Finally, tell LiveAdmin what Ecto repo to use to run queries in your `runtime.ex`:

```
config :live_admin, ecto_repo: MyApp.Repo
```

That's it, now an admin UI for `MyApp.Foo` will be available at `/admin/foos`.

## (Optional) Configuration

You may want more control over how your resources appear in the UI, or which fields are editable.
If you want to customize the behavior of one or more resources, including how records
are rendered or changes are validated, or to add custom behaviors, there are a variety of configuration options
available. This includes component overrides if you would like to completely control
every aspect of a particular resource view, like the edit form.
For a list of base configuration and expected values, see `LiveAdmin.base_configs_schema/0`.


For additional convenience and control, configuration in LiveAdmin can be set at 3 different levels.
From more specific to more general, they are:

### Resource

The second argument passed to `use LiveAdmin.Resource` will configure only that specific resource,
in any LiveView it is used.

Extra options:

* `schema` - use to set the schema for the resource (default: calling module)
* `preload` - manually choose which associations to preload (default: all `belongs_to` associations)

### Scope

The second argument passed to `live_admin` will configure defaults for all resources in the group (wrapped in a [Live Session](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html#live_session/3)) that do not already specify the same configuration.

Extra options:

* `title` - title to display in nav (default: "LiveAdmin")

### Application

App config can be used to set a global default to apply to all resources unless overridden in their individual config, or the LiveAdmin instance.

Extra options:

* `session_store` - a module implementing the `LiveAdmin.Session.Store` behavior, used to persist session data (default: LiveAdmin.Session.Agent)
* `css_overrides` - a binary or MFA identifying a function that returns CSS to be appended to app css
* `gettext_backend` - a module implementing the [Gettext API](https://hexdocs.pm/gettext/Gettext.html#module-gettext-api) that will be used for translations

*For concrete examples of the various config options and to see them in action, consult the [development app](#development).*

## Features

### Multi tenancy

To enable Multi tenant support, simply implement a `prefixes/0` function in your Ecto Repo module that returns a list of prefixes.
A dropdown will be added to the top nav bar that will allow you to switch between tenants.

### i18n

LiveAdmin wraps all static strings in the UI with Gettext calls, but currently it does *not* provide any locales by default.
To enable i18n, implement a `locales/0` function returning a list of binary locale names on your Gettext Backend module.

Unfortunately it is not currently possible to use Gettext's utilities to automatically extract the pot files so you will need to do this manually.
To avoid conflicts with your own app's translations, it is recommended to use a separate Gettext backend for LiveAdmin.

## Development

This repo has been configured to run the application in [Docker](https://www.docker.com/) using [Compose](https://docs.docker.com/compose/).

The Phoenix app is running the `app` service, so all mix command should be run there. Examples:

* `docker compose run app mix test`

---

README generated with [docout](https://github.com/tfwright/docout)
