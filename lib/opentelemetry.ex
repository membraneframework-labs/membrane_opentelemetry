defmodule Membrane.OpenTelemetry do
  require OpenTelemetry

  @enabled Application.compile_env(:membrane_opentelemetry, :enabled, false)

  @type span_name :: String.t()

  defmacro start_span(name, opts \\ quote(do: %{})) do
    if enabled(),
      do: do_start_span(name, opts),
      else: default_macro([name, opts])
  end

  defmacro end_span(name) do
    if enabled(),
      do: do_end_span(name),
      else: default_macro([name])
  end

  defmacro set_current_span(name) do
    if enabled(),
      do: do_set_current_span(name),
      else: default_macro([name])
  end

  defmacro set_attribute(name, key, value) do
    if enabled(),
      do: do_set_attribute(name, key, value),
      else: default_macro([name, key, value])
  end

  defmacro set_attributes(name, attributes) do
    if enabled(),
      do: do_set_attributes(name, attributes),
      else: default_macro([name, attributes])
  end

  defmacro add_event(name, event, attributes) do
    if enabled(),
      do: do_add_event(name, event, attributes),
      else: default_macro([name, event, attributes])
  end

  defmacro add_events(name, events) do
    if enabled(),
      do: do_add_events(name, events),
      else: default_macro([name, events])
  end

  @spec register() :: :ok
  def register() do
    Membrane.OpenTelemetry.Monitor.start(self())
    :ok
  end

  defp enabled(), do: @enabled

  defp do_start_span(name, opts) do
    quote do
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
      with span when span != nil <- unquote(__MODULE__).ETSUtils.pop_span(unquote(name)) do
        OpenTelemetry.Tracer.set_current_span(span)
        OpenTelemetry.Tracer.end_span()
      end
    end
  end

  defp do_set_current_span(name) do
    quote do
      unquote(__MODULE__).ETSUtils.get_span(unquote(name))
      |> OpenTelemetry.Tracer.set_current_span()
    end
  end

  defp do_set_attribute(name, key, value) do
    call_with_current_span(
      name,
      fn -> OpenTelemetry.Tracer.set_attribute(key, value) end
    )
  end

  defp do_set_attributes(name, attributes) do
    call_with_current_span(
      name,
      fn -> OpenTelemetry.Tracer.set_attributes(attributes) end
    )
  end

  defp do_add_event(name, event, attributes) do
    call_with_current_span(
      name,
      fn -> OpenTelemetry.Tracer.add_event(event, attributes) end
    )
  end

  defp do_add_events(name, events) do
    call_with_current_span(
      name,
      fn -> OpenTelemetry.Tracer.add_events(events) end
    )
  end

  defp call_with_current_span(name, function) do
    quote do
      old_current_span = OpenTelemetry.Tracer.current_span_ctx()

      span = unquote(__MODULE__).ETSUtils.get_span(unquote(name))
      OpenTelemetry.Tracer.set_current_span(span)
      unquote(function).()

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
