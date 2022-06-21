defmodule Membrane.OpenTelemetry.ETSUtils do
  @moduledoc false

  @ets_table_name Membrane.OpenTelemetry.ProcessSpansTable
  @pdict_key_prefix :__membrane_opentelemetry_pdict_key_prefix__

  @spec setup_ets_table() :: :ok
  def setup_ets_table() do
    :ets.new(@ets_table_name, [
      :public,
      :bag,
      :named_table,
      {:write_concurrency, true}
    ])

    :ok
  end

  @spec delete_ets_table() :: :ok
  def delete_ets_table() do
    :ets.delete(@ets_table_name)
    :ok
  end

  @spec store_span(Membrane.OpenTelemetry.span_name(), :opentelemetry.span_ctx()) :: :ok
  def store_span(name, span) do
    :ets.insert(@ets_table_name, {self(), span})
    pdict_key(name) |> Process.put(span)

    :ok
  end

  @spec pop_span(Membrane.OpenTelemetry.span_name()) :: :opentelemetry.span_ctx() | nil
  def pop_span(name) do
    span = pdict_key(name) |> Process.delete()
    if span, do: :ets.delete_object(@ets_table_name, {self(), span})

    span
  end

  @spec get_span(Membrane.OpenTelemetry.span_name()) :: :opentelemetry.span_ctx() | nil
  def get_span(name) do
    pdict_key(name) |> Process.get()
  end

  @spec get_process_spans(pid()) :: [:opentelemetry.span_ctx()]
  def get_process_spans(pid \\ self()) do
    :ets.lookup(@ets_table_name, pid)
  end

  @spec delete_process_spans(pid()) :: :ok
  def delete_process_spans(pid \\ self()) do
    :ets.delete(@ets_table_name, pid)
    :ok
  end

  defp pdict_key(name), do: {@pdict_key_prefix, name}
end
