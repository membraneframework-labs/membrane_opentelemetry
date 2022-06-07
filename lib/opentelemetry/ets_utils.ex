defmodule Membrane.OpenTelemetry.ETSUtils do
  @moduledoc false

  @process_spans_table Membrane.OpenTelemetry.ProcessSpansTable
  @spans_by_name_table Membrane.OpenTelemetry.SpansMapTable

  @spec create_ets_tables() :: :ok
  def create_ets_tables() do
    :ets.new(@process_spans_table, [
      :public,
      :bag,
      :named_table,
      {:write_concurrency, true}
    ])

    :ets.new(@spans_by_name_table, [:public, :set, :named_table])

    :ok
  end

  @spec store_span(Membrane.OpenTelemetry.span_name(), :opentelemetry.span_ctx()) :: :ok
  def store_span(name, pid \\ self(), span) do
    :ets.insert(@process_spans_table, {pid, span})
    :ets.insert(@spans_by_name_table, {{name, pid}, span})
    :ok
  end

  @spec get_span(Membrane.OpenTelemetry.span_name()) :: :opentelemetry.span_ctx() | nil
  def get_span(name, pid \\ self()) do
    case :ets.lookup(@spans_by_name_table, {name, pid}) do
      [span] -> span
      [] -> nil
    end
  end

  @spec get_process_spans(pid()) :: [:opentelemetry.span_ctx()]
  def get_process_spans(pid \\ self()) do
    :ets.lookup(@process_spans_table, pid)
  end
end
