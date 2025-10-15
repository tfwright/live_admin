defmodule LiveAdmin.Components do
  use Phoenix.Component
  use PhoenixHTMLHelpers

  import Phoenix.HTML.Form
  import LiveAdmin

  alias Phoenix.LiveView.JS
  alias LiveAdmin.Components.Container.Form.{ArrayInput, SearchSelect}

  attr(:id, :string, required: true)
  attr(:label, :string, required: true)
  attr(:items, :list, required: true)
  slot(:inner_block)

  def drop_down(assigns) do
    ~H"""
    <details
      class="btn-select"
      id={@id}
      phx-click-away={Phoenix.LiveView.JS.remove_attribute("open", to: "##{@id}")}
    >
      <summary>{@label}</summary>
      <div class="drop-menu">
        <%= for item <- @items do %>
          {render_slot(@inner_block, item)}
        <% end %>
      </div>
    </details>
    """
  end

  def form_grid(assigns) do
    ~H"""
    <div>
      <div class="form-grid">
        <%= for {field, type, opts} <- @fields, editable_inline?(@form, field, type) do %>
          <div class={"form-field #{if @form.errors[field], do: "error"}"}>
            <div class="form-label">
              {label(@form, field, field |> humanize() |> trans())}
            </div>
            <%= if supported_type?(type) do %>
              <.input
                form={@form}
                type={type}
                field={field}
                resource={@resource}
                resources={@resources}
                session={@session}
                prefix={@prefix}
                repo={@repo}
                config={@config}
                disabled={false}
              />
            <% else %>
              {textarea(@form, field,
                rows: 1,
                disabled: true,
                value: @form[field]
              )}
            <% end %>
            <span class="error-message">
              {Enum.map_join(@form[field].errors, ", ", &elem(&1, 0))}
            </span>
          </div>
        <% end %>
      </div>
      <%= for {field, {_,{Ecto.Embedded, embed}}, opts} <- @fields, {_, val} = Ecto.Changeset.fetch_field(@form.source, field) do %>
        <.embed_form
          field={field}
          embed={embed}
          form={@form}
          value={val}
          resource={@resource}
          resources={@resources}
          config={@config}
          session={@session}
          prefix={@prefix}
          repo={@repo}
          target={@target}
        />
      <% end %>
    </div>
    """
  end

  def embed_form(assigns) do
    ~H"""
    <div class="embed-container">
      <div class="embed-section-wrapper">
        <div class="embed-section-title-wrapper">
          <h2 class="embed-section-title">{@field |> humanize() |> trans()}</h2>
        </div>
        <%= if @value do %>
          <.inputs_for :let={embed_form} field={@form[@field]} skip_hidden={true}>
            <%= if sortable?(@value) do %>
              <div class="drop-zone" data-idx={embed_form.index}>{trans("Move here")}</div>
            <% end %>
            <div
              class={"embed-section #{if assigns[:cycle], do: "odd"}"}
              draggable={if sortable?(@value), do: "true"}
              data-idx={embed_form.index}
            >
              <%= if sortable?(@value) do %>
                <input
                  type="hidden"
                  name={@form[LiveAdmin.View.sort_param_name(@field)].name <> "[]"}
                  value={embed_form.index}
                />
              <% end %>
              <button
                type="button"
                class="remove-icon"
                name={@form[LiveAdmin.View.drop_param_name(@field)].name <> if @embed.cardinality == :one, do: "", else: "[]"}
                value={if @embed.cardinality == :one, do: "", else: embed_form.index}
                phx-click={JS.dispatch("change")}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                >
                  <circle cx="12" cy="12" r="10"></circle>
                  <line x1="15" y1="9" x2="9" y2="15"></line>
                  <line x1="9" y1="9" x2="15" y2="15"></line>
                </svg>
              </button>
              <%= if sortable?(@value) do %>
                <button type="button" class="drag-icon">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <line x1="3" y1="9" x2="21" y2="9"></line>
                    <line x1="3" y1="15" x2="21" y2="15"></line>
                  </svg>
                </button>
              <% end %>
              <.form_grid
                form={embed_form}
                resource={@resource}
                resources={@resources}
                session={@session}
                prefix={@prefix}
                repo={@repo}
                config={@config}
                fields={
                  Enum.map(
                    @embed.related.__schema__(:fields),
                    &{&1, @embed.related.__schema__(:type, &1), []}
                  )
                }
                target={@target}
                cycle={!assigns[:cycle]}
              />
            </div>
            <%= if sortable?(@value) && embed_form.index + 1 == length(@value)  do %>
              <div class="drop-zone" data-idx={length(@value)}>{trans("Move here")}</div>
            <% end %>
          </.inputs_for>
        <% end %>
      </div>
    </div>
    <%= if @embed.cardinality == :many || (@form[@field].value in ["", nil]) do %>
      <button
        type="button"
        class="add-section-btn"
        name={@form[LiveAdmin.View.sort_param_name(@field)].name <> if @embed.cardinality == :one, do: "", else: "[]"}
        value="new"
        phx-click={JS.dispatch("change")}
        phx-target={@target}
      >
        <span>+</span>
        {@field |> humanize() |> trans()}
      </button>
    <% end %>
    """
  end

  defp sortable?(val) when is_list(val) and length(val) > 1, do: true
  defp sortable?(_), do: false

  defp editable_inline?(form, field, type) when type in [:id, :binary_id],
    do: form.data |> Ecto.primary_key() |> Keyword.keys() |> Enum.member?(field) |> Kernel.not()

  defp editable_inline?(_, _, {_, {Ecto.Embedded, _}}), do: false

  defp editable_inline?(_, _, :map), do: false

  defp editable_inline?(_, _, _), do: true

  defp input(assigns = %{type: id}) when id in [:id, :binary_id] do
    assoc_resource =
      associated_resource(
        LiveAdmin.fetch_config(assigns.resource, :schema, assigns.session),
        assigns.field,
        assigns.resources,
        :resource
      )

    if assoc_resource do
      value = assigns.form[assigns.field].value

      selected_option =
        case value do
          empty when empty in [nil, ""] ->
            {nil, nil}

          key ->
            assoc_record =
              LiveAdmin.Resource.find!(key, assoc_resource, assigns.prefix, assigns.repo, assigns.config)

            {key, record_label(assoc_record, assoc_resource, assigns.config)}
        end

      assigns = assign(assigns, selected_option: selected_option, resource: assoc_resource)

      ~H"""
      <.live_component
        module={SearchSelect}
        id={@form[@field].id}
        name={@form[@field].name}
        disabled={@disabled}
        selected_option={@selected_option}
        options={{__MODULE__, :search_select_options, [@resource, @prefix, @session, @repo, @config]}}
      />
      """
    else
      ~H"""
      <input type="number" class="form-input" name={@form[@field].name} value={@form[@field].value} />
      """
    end
  end

  defp input(assigns = %{type: {:array, :string}}) do
    ~H"""
    <.live_component
      module={ArrayInput}
      id={input_id(@form, @field)}
      form={@form}
      field={@field}
      disabled={@disabled}
    />
    """
  end

  defp input(assigns = %{type: :string}) do
    ~H"""
    <textarea name={@form[@field].name} class="form-textarea" phx-debounce={500}>{@form[@field].value}</textarea>
    """
  end

  defp input(assigns = %{type: :boolean}) do
    ~H"""
    <% normalize_value(:boolean, @form[@field].value) %>
    <div class="switch-container">
      <input
        type="radio"
        class="switch-left"
        name={@form[@field].name}
        id={@form[@field].id <> "_left"}
        checked={normalize_value("checkbox", @form[@field].value) == false}
        value="false"
      />
      <input
        type="radio"
        class="switch-center"
        name={@form[@field].name}
        id={@form[@field].id <> "_center"}
        checked={@form[@field].value in [nil, ""]}
        value=""
      />
      <input
        type="radio"
        class="switch-right"
        name={@form[@field].name}
        id={@form[@field].id <> "_right"}
        checked={normalize_value("checkbox", @form[@field].value) == true}
        value="true"
      />

      <div class="switch">
        <div class="switch-background">
          <div class="bg-section left"></div>
          <div class="bg-section center"></div>
          <div class="bg-section right"></div>
        </div>
        <div class="switch-handle"></div>
        <label for={@form[@field].id <> "_left"} class="label-area left"></label>
        <label for={@form[@field].id <> "_center"} class="label-area center"></label>
        <label for={@form[@field].id <> "_right"} class="label-area right"></label>
      </div>
    </div>
    """
  end

  defp input(assigns = %{type: :date}) do
    ~H"""
    <input type="date" class="form-input" name={@form[@field].name} value={@form[@field].value} />
    """
  end

  defp input(assigns = %{type: number}) when number in [:integer, :id, :float] do
    ~H"""
    <input type="number" class="form-input" name={@form[@field].name} value={@form[@field].value} />
    """
  end

  defp input(assigns = %{type: type}) when type in [:naive_datetime, :utc_datetime] do
    ~H"""
    <input
      type="datetime-local"
      class="form-input"
      name={@form[@field].name}
      value={@form[@field].value}
    />
    """
  end

  defp input(assigns = %{type: {_, {Ecto.Enum, %{mappings: mappings}}}}) do
    assigns = assign(assigns, :mappings, mappings)

    ~H"""
    <select name={@form[@field].name} class="form-select">
      <option value="" />
      <%= for {k, v} <- @mappings do %>
        <option value={k} selected={@form[@field].value == k}>{v}</option>
      <% end %>
    </select>
    """
  end

  defp input(assigns = %{type: {:array, {_, {Ecto.Enum, %{mappings: mappings}}}}}) do
    assigns = assign(assigns, :mappings, mappings)

    ~H"""
    <select name={@form[@field].name <> "[]"} class="form-select" multiple={true}>
      <%= for {k, v} <- @mappings do %>
        <option value={k} selected={Enum.member?(@form[@field].value || [], k)}>{v}</option>
      <% end %>
    </select>
    """
  end

  defp input(assigns) do
    ~H"""
    NO INPUT
    """
  end

  def error(assigns) do
    ~H"""
    <div class="error-box">
      <div class="error-header">
        <div class="error-icon">
          <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="12" cy="12" r="10" stroke="#ef4444" stroke-width="2"></circle>
            <path d="M12 8V12" stroke="#ef4444" stroke-width="2" stroke-linecap="round"></path>
            <circle cx="12" cy="16" r="1" fill="#ef4444"></circle>
          </svg>
        </div>
        <h3>{@title}</h3>
      </div>

      <p class="error-message">{@details}</p>
    </div>
    """
  end

  def expand_modal(assigns) do
    ~H"""
    <div id={@id} phx-hook="CopyField">
      <.modal id={@id <> "-modal"}>
        <:title>{@title}<span>{@field}</span></:title>
        <div class="expand-content">{safe_render(@value)}</div>
        <span
          class="copy-icon"
          data-clipboard-target={"##{@id}-modal .expand-content"}
        >
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
          >
            <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
          </svg>
        </span>
      </.modal>
      <span
        class="expand-icon"
        phx-click={JS.show(to: "##{@id}-modal", display: "flex")}
      >
        <svg
          width="14"
          height="14"
          viewBox="0 0 14 14"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M6 6L2 2M2 2L2 4M2 2L4 2"
            stroke="currentColor"
            stroke-width="1"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M8 6L12 2M12 2L12 4M12 2L10 2"
            stroke="currentColor"
            stroke-width="1"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M6 8L2 12M2 12L2 10M2 12L4 12"
            stroke="currentColor"
            stroke-width="1"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
          <path
            d="M8 8L12 12M12 12L12 10M12 12L10 12"
            stroke="currentColor"
            stroke-width="1"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </span>
    </div>
    """
  end

  def modal(assigns) do
    ~H"""
    <div class="modal" id={@id}>
      <div
        class="modal-content"
        phx-click-away={JS.hide(to: "#" <> @id)}
      >
        <div class="modal-header">
          <h3 class="modal-title">
            {render_slot(@title)}
          </h3>
          <button
            class="modal-close"
            phx-click={JS.hide(to: "#" <> @id)}
          >
            &times;
          </button>
        </div>
        <div class="modal-body">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  def function_control(assigns) do
    assigns = assign(assigns, :modalize, assigns.extra_arg_count > 0 || Enum.any?(assigns.docs))

    ~H"""
    <div>
      <%= if @modalize do %>
        <.modal id={"#{@type}-#{@name}-modal"}>
          <:title>{@name |> to_string() |> humanize()}</:title>
          <.form
            for={Phoenix.Component.to_form(%{})}
            phx-submit={@type}
            phx-target={assigns[:target]}
            class="form-line"
          >
            <%= for {_lang, doc} <- @docs do %>
              <div class="docs">{doc}</div>
            <% end %>
            <input type="hidden" name="name" value={@name} />
            <%= if @extra_arg_count > 0 do %>
              <h2 class="form-title">{trans("Arguments")}</h2>
              <%= for num <- 1..@extra_arg_count do %>
                <div class="form-group">
                  <label>{num}</label>
                  <textarea class="form-textarea" name="args[]" required></textarea>
                </div>
              <% end %>
            <% end %>
            <div class="button-group">
              <button type="submit" class="btn btn-primary">{trans("Submit")}</button>
            </div>
          </.form>
        </.modal>
      <% end %>
      <span
        class="drop-link"
        phx-click={
          if @modalize,
            do: JS.show(to: "##{@type}-#{@name}-modal", display: "flex"),
            else: JS.push(@type, value: %{"name" => @name}, page_loading: true, target: @target)
        }
        data-confirm={if @modalize, do: nil, else: trans("Are you sure you?")}
      >
        {trans(humanize(@name))}
      </span>
    </div>
    """
  end

  def search_select_options(q, resource, prefix, session, repo, config) do
    resource
    |> LiveAdmin.Resource.list([prefix: prefix, search: q], session, repo, config)
    |> elem(0)
    |> Enum.map(
      &{Map.fetch!(&1, LiveAdmin.primary_key!(resource)), record_label(&1, resource, config)}
    )
  end

  @supported_primitive_types [
    :string,
    :boolean,
    :date,
    :integer,
    :naive_datetime,
    :utc_datetime,
    :id,
    :binary_id,
    :float
  ]
  def supported_type?(type) when type in @supported_primitive_types, do: true
  def supported_type?(:map), do: true
  def supported_type?({:array, _}), do: true
  def supported_type?({_, {Ecto.Embedded, _}}), do: true
  def supported_type?({_, {Ecto.Enum, _}}), do: true
  def supported_type?(_), do: false
end
