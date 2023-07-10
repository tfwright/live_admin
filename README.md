<!-- This README was generated with docout (https://github.com/tfwright/docout). Edits should be made to the formatter instead of this file, other changes will be overridden on compile. -->

# LiveAdmin

[![hex package](https://img.shields.io/hexpm/v/live_admin.svg)](https://hex.pm/packages/live_admin)
[![CI status](https://github.com/tfwright/live_admin/workflows/CI/badge.svg)](https://github.com/tfwright/live_admin/actions)

An admin UI for Phoenix applications built on [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view) and [Ecto](https://github.com/elixir-ecto/ecto/).

Significant features:

* First class support for multi tenant applications via Ecto's `prefix` option
* Overridable views and API
* Easily add custom actions at the schema and record level
* Ability to edit (nested) embedded schemas
* i18n via [Gettext](elixir-gettext/gettext)

## Installation

First, ensure your Phoenix app has been configured to use [LiveView](https://hexdocs.pm/phoenix_live_view/installation.html).

Add to your app's `deps`:

```
{:live_admin, "~> 0.9.3"}
```

Configure a module to act as a LiveAdmin resource:

```
defmodule MyApp.MyResource do
  use LiveAdmin.Resource, schema: MyApp.Schema
end
```

In your Phoenix router, add the resource to a LiveAdmin instance:

```
import LiveAdmin.Router

live_admin "/my_admin" do
  admin_resource "/my_schemas", MyApp.MyResource
end
```

Finally, tell LiveAdmin what Ecto repo to use to run queries in your `runtime.ex`: `config :live_admin, ecto_repo: MyApp.Repo`

That's it, now an admin UI for `MyApp.Schema` will be available at `/my_admin/my_schemas`.

## Configuration

One of the main goals of LiveAdmin is to require as little config as possible.
It should work out of the box, with only the above, for the vast majority of common
app admin needs.

However, if you want to customize the behavior of one or more resources, including how records
are rendered or changes are validated, or to add custom behaviors, there are a variety of configuration options
available. This includes component overrides if you would like to completely control
every aspect of a particular resource view, like the edit form. For a complete list of options, see the `LiveAdmin.Resource` docs.

For additional convenience and control, configuration in LiveAdmin can be set at 3 different levels.
From most specific to most general, they are resource, admin instance, and global.

For concrete examples of the various config options and to see them in action, consult the [development app](#development-environment).

### Resource

The second argument passed to `use LiveAdmin.Resource` will configure only that specific resource,
in any LiveView it is used. If the module is not an Ecto schema, the `:schema` option must be passed.
If you would like the same schema to behave differently in different LiveAdmin instances, or different
routes in the same instance, you must create multiple resource modules to contain that configuration.

### Admin instance

The second argument passed to `live_admin` will configure defaults for all resources in the group
that do not specify the same configuration. Currently only component overrides can be configured at this level.

### Global

All resource configuration options can also be set in the LiveAdmin app runtime config. This will set a global
default to apply to all resources unless overridden in their individual config, or the LiveAdmin instance.

Additionally, the following options can only be set at the global level:

* `prefix_options` - a list or MFA specifying `prefix` options to be passed to Ecto functions
* `css_overrides` - a binary or MFA identifying a function that returns CSS to be appended to app css
* `session_store` - a module implementing the `LiveAdmin.Session.Store` behavior, used to persist session data
* `gettext_backend` - a module implementing the [Gettext API](https://hexdocs.pm/gettext/Gettext.html#module-gettext-api). It is expected to implement `locales/0` returning a list of binary locale names

## i18n

LiveAdmin wraps all static strings in the UI with Gettext calls, but currently it does *not* provide any locales by default, so you will need
to make sure they have been set up correctly for a custom backend. Unfortunately it is not currently possible to use
Gettext's utilities to automatically extract the pot files so you will need to do this manually.
To avoid conflicts with your own app's translations, it is recommended to create separate Gettext backends for LiveAdmin.

## Development environment

This repo has been configured to run the application in Docker. Simply run `docker compose up` and navigate to http://localhost:4000

The Phoenix app is running the `app` service, so all mix command should be run there. Examples:

* `docker compose run web mix test`

---

README generated with [docout](https://github.com/tfwright/docout)
