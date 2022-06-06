defmodule Membrane.OpenTelemetry do
  require OpenTelemetry

  @enabled Application.compile_env(:membrane_opentelemetry, :enabled, false)
  @span :__membrane_optentelemetry_span__

  @type span_name :: String.t()

  defmacro start_span(name, opts \\ quote(do: %{})) do
    if @enabled,
      do: do_start_span(name, opts),
      else: default_macro([name, opts])
  end

  defmacro end_span(name, timestamp \\ quote(do: :undefined)) do
    if @enabled,
      do: do_end_span(name, timestamp),
      else: default_macro([name, timestamp])
  end

  defp do_start_span(name, opts) do
    quote do
      with %{parent: parent_name} when parent <- unquote(opts) do
        parent_span = unquote(__MODULE__).get_span(parent_name)
        OpenTelemetry.Tracer.set_current_span(parent_span)
      end

      new_span = OpenTelemetry.Tracer.start_span(name)
      unquote(__MODULE__).store_span(unquote(name), span)
    end
  end

  defp do_end_span(name, timestamp) do
    quote do
      unquote(__MODULE__).get_span(unquote(name))
      |> OpenTelemetry.Tracer.set_current_span()

      OpenTelemetry.Tracer.end_span(unquote(timestamp))
    end
  end

  defp default_macro(values) do
    quote do
      fn ->
        _unused = unquote(values)
      end
    end
  end

  @spec store_span(span_name(), :opentelemetry.span_ctx()) :: :ok
  def store_span(name, span) do
    Process.put({@span, name}, span)
    :ok
  end

  @spec get_span(span_name()) :: :opentelemetry.span_ctx() | nil
  def get_span(name) do
    Process.get({@span, name})
  end
end
