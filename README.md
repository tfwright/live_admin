# LiveAdmin

An admin UI for Phoenix applications built on [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view) and [Ecto](https://github.com/elixir-ecto/ecto/).

Significant features:

* First class support for multi tenant applications via Ecto's `prefix` option
* Overridable views and API
* Easily add custom actions at the schema and record level
* Ability to edit (nested) embedded schemas

## Installation

Add to your app's `deps`:

```
{:live_admin, "~> 0.1"}
```

Add the following to your Phoenix router:

```
live_admin "/admin", resources: [MyApp.SomeEctoSchema]
```

To customize a resource, pass a two element tuple when the schema module as the first element, and a keyword list of options is the second: `{MyApp.SomeEctoSchema, opts}`

Currently supported options:

* `title_with` - a binary or MFA specifying how to identify the resource
* `label_with` - a binary or MFA specifying how to identify individual records
* `create_with` - an atom or MFA that identifies the function that implements creating a new record
* `update_with` - an atom or MFA that identifies the function that implements updating an existing record
* `validate_with` - an atom or MFA that identifies the function that implements validating an Ecto changeset for the resource
* `hidden_fields` - a list of fields that should not be displayed in the UI
* `immutable_fields` - a list of fields that should not be editable in forms
* `actions` - actions to perform on a record
* `tasks` - actions to perform on a resource
* `components` - overrides for specific views

## App config

* `ecto_repo` - the Ecto repo to use for db operations
* `prefix_options` - a list or MFA specifying `prefix` options to be passed to Ecto functions

In addition, most resource configuration can be set here in order to set a global default to apply to all resources unless overriden in their individual config.

Example:

```
config :phoenix_live_admin,
  ecto_repo: MyApp.Repo,
  prefix_options: {MyApp.Accounts, :list_tenant_prefixes, []},
  immutable_fields: [:id, :inserted_at, :updated_at],
  label_with: :name
```

See [development app](/dev.exs) for more example configuration.
