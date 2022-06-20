defmodule Membrane.OpenTelemetry do
  @moduledoc """
  Defines macros for operations on OpenTelemetry spans.
  Provided macros evalueate to appropriate calls to OpenTelemetry functions or to nothing, depending on config values
  """

  require OpenTelemetry
  require OpenTelemetry.Tracer
  require OpenTelemetry.Ctx

  @enabled Application.compile_env(:membrane_opentelemetry, :enabled, false)

  @type span_name :: String.t()

  @doc """
  Starts a new span. If the second argument contains value `parent` under key `:parent`, then span named `parent` will be the parent span of the newly created one.
  """
  defmacro start_span(name, opts \\ quote(do: %{})) do
    if enabled(),
      do: do_start_span(name, opts),
      else: default_macro([name, opts])
  end

  @doc """
  Ends a span.
  """
  defmacro end_span(name) do
    if enabled(),
      do: do_end_span(name),
      else: default_macro([name])
  end

  @doc """
  Sets specific span with specific name as current one.
  """
  defmacro set_current_span(name) do
    if enabled(),
      do: do_set_current_span(name),
      else: default_macro([name])
  end

  @doc """
  Sets an attribute value in a span with a specific name.
  """
  defmacro set_attribute(name, key, value) do
    if enabled(),
      do: do_set_attribute(name, key, value),
      else: default_macro([name, key, value])
  end

  @doc """
  Sets attributes in a span with specific name.
  """
  defmacro set_attributes(name, attributes) do
    if enabled(),
      do: do_set_attributes(name, attributes),
      else: default_macro([name, attributes])
  end

  @doc """
  Adds an event to a span with a specific name.
  """
  defmacro add_event(name, event, attributes) do
    if enabled(),
      do: do_add_event(name, event, attributes),
      else: default_macro([name, event, attributes])
  end

  @doc """
  Adds events to a span with a specific name.
  """
  defmacro add_events(name, events) do
    if enabled(),
      do: do_add_events(name, events),
      else: default_macro([name, events])
  end

  @doc """
  Ensures, that every span started in the process calling this function, will be implicite closed after the process end.
  Should be called in every process, that will execute any other function or macro from this module.
  """
  defmacro register() do
    if enabled() do
      quote do
        unquote(__MODULE__).Monitor.start(self())
      end
    end
  end

  @doc """
  Attaches `otel_ctx`. See docs for `OpenTelemetry.Ctx.attach/1`.
  """
  defmacro attach(ctx) do
    if enabled() do
      quote do
        require OpenTelemetry.Ctx
        OpenTelemetry.Ctx.attach(unquote(ctx))
      end
    else
      default_macro(ctx)
    end
  end

  defp enabled(), do: @enabled

  defp do_start_span(name, opts) do
    quote do
      require OpenTelemetry.Tracer

      with %{parent: parent_name} when parent_name != nil <- unquote(opts) do
        parent_span = unquote(__MODULE__).ETSUtils.get_span(parent_name)
        OpenTelemetry.Tracer.set_current_span(parent_span)
      end

      new_span = OpenTelemetry.Tracer.start_span(unquote(name))
      unquote(__MODULE__).ETSUtils.store_span(unquote(name), new_span)
      OpenTelemetry.Tracer.set_current_span(new_span)
    end
  end

  defp do_end_span(name) do
    quote do
      require OpenTelemetry.Tracer

      with span when span != nil <- unquote(__MODULE__).ETSUtils.pop_span(unquote(name)) do
        OpenTelemetry.Tracer.set_current_span(span)
        OpenTelemetry.Tracer.end_span()
      end
    end
  end

  defp do_set_current_span(name) do
    quote do
      require OpenTelemetry.Tracer

      unquote(__MODULE__).ETSUtils.get_span(unquote(name))
      |> OpenTelemetry.Tracer.set_current_span()
    end
  end

  defp do_set_attribute(name, key, value) do
    call_with_current_span(
      name,
      &OpenTelemetry.Tracer.set_attribute/2,
      [key, value]
    )
  end

  defp do_set_attributes(name, attributes) do
    call_with_current_span(
      name,
      &OpenTelemetry.Tracer.set_attributes/1,
      [attributes]
    )
  end

  defp do_add_event(name, event, attributes) do
    call_with_current_span(
      name,
      &OpenTelemetry.Tracer.add_event/2,
      [event, attributes]
    )
  end

  defp do_add_events(name, events) do
    call_with_current_span(
      name,
      &OpenTelemetry.Tracer.add_events/1,
      [events]
    )
  end

  defp call_with_current_span(name, function, args) do
    quote do
      require OpenTelemetry.Tracer

      old_current_span = OpenTelemetry.Tracer.current_span_ctx()

      span = unquote(__MODULE__).ETSUtils.get_span(unquote(name))
      OpenTelemetry.Tracer.set_current_span(span)
      apply(unquote(function), unquote(args))

      OpenTelemetry.Tracer.set_current_span(old_current_span)
    end
  end

  defp default_macro(values) do
    quote do
      fn ->
        _unused = unquote(values)
      end
    end
  end
end
