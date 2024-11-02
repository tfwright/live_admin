<!-- This README was generated with docout (https://github.com/tfwright/docout). Edits should be made to the formatter instead of this file, other changes will be overridden on compile. -->

# LiveAdmin

[![hex package](https://img.shields.io/hexpm/v/live_admin.svg)](https://hex.pm/packages/live_admin)
[![CI status](https://github.com/tfwright/live_admin/workflows/CI/badge.svg)](https://github.com/tfwright/live_admin/actions)

An admin UI for Phoenix applications built on [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view) and [Ecto](https://github.com/elixir-ecto/ecto/).

Significant features:

* First class support for multi tenant applications via [Ecto's prefix option](https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html#per-query-and-per-struct-prefixes)
* Persistent user "sessions"
* Overridable views, styles, and API
* Custom actions at the resource and record level, with support for dynamic inputs
* Edit (nested) embedded schemas
* i18n via [Gettext](https://github.com/elixir-gettext/gettext)

See for yourself, try out the [demo app](#development)

## (Required) Installation

The overriding design goal of LiveAdmin is to require as little config as possible.
Its primary intended use case is an internal tool for managing application data.
It should be useable out of the box for this purpose, although it supports significant *optional* customization.
If you are already [running LiveView](https://hexdocs.pm/phoenix_live_view/installation.html) in your application, it should only take a few minutes to expose a UI for your resources.

1. Add to your app's `deps`:

    ```elixir
    {:live_admin, "~> 0.12.0"}
    ```

2. Configure module(s) to act as a LiveAdmin resource:

    ```elixir
    defmodule MyApp.Admin.Foo do
      use LiveAdmin.Resource, schema: MyApp.Foo
    end
    ```

    *Note: if your module is an Ecto schema you can omit the `schema` option.*

3. In your Phoenix router, inside a scope configured to run LiveView (`:browser` if you followed the default installation), add your resources to a LiveAdmin instance:

    ```elixir
    import LiveAdmin.Router

    ...

    scope "/" do
      pipe_through :browser

      live_admin "/admin" do
        admin_resource "/foos", MyApp.Admin.Foo
        # more resources
      end
    end
    ```

4. Finally, tell LiveAdmin what Ecto repo to use to run queries in your `runtime.ex`:

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

* `actions` - functions that operate on a specific record
* `tasks` - functions that operate on a resource as a whole
* `list_with` - function used to fetch records
* `render_with` - function used to encode field values in views
* `create_with` - function used to insert a record
* `update_with` - function used to update a record
* `validate_with` - function used to validate a changeset
* `label_with` - function used to refer to records in views
* `title_with` - function used to encode resource module names in views
* `hidden_fields` - list of fields not to show anywhere in views
* `immutable_fields` - list of fields not to be editable in forms
* `components` - override portions of the UI
* `ecto_repo` - module used to execute queries

*For more information about how to use options, see documentation for `LiveAdmin.base_configs_schema/0`.*

---

Configuration in LiveAdmin can be set at 3 different levels. From more local to more global, they are:

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

## Features

### Annotated actions and tasks with extra arguments

In addition to the record or resource, respectively, functions configured to act as actions or tasks also receive the `LiveAdmin.Session` object.
This allows them to implement varying behavior based on user-specific state (like their id or the currently selected prefix).
However, they can also support an arbitrary number of extra arguments to support user *specified* values.
LiveAdmin will prompt the user when the action or task is selected and display any function docs.

```
def MyModule
  use LiveAdmin.Resource,
    actions: [{__MODULE__, :my_action, 4}],
    # ...

  @doc """
  This text will be shown to the user when running the action
  """
  def my_action(record, session, extra, extra2) do
    # do something
  end
end
```

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

To run the [demo app](/dev.exs):

* `docker compose up`
* Navigate your preferred browser to localhost:4000

---

README generated with [docout](https://github.com/tfwright/docout)
