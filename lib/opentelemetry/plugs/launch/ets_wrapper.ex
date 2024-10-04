defmodule Membrane.OpenTelemetry.Plugs.Launch.ETSWrapper do
  @pid_to_span_ets :__membrane_opentelemetry_plugs_launch_pid_to_span__
  @pipeline_offsprings_ets :__membrane_opentelemetry_plugs_launch_pid_to_span__

  @spec setup_ets_table() :: :ok
  def setup_ets_table() do
    :ets.new(@pid_to_span_ets, [
      :public,
      # unique keys
      :set,
      :named_table,
      {:read_concurrency, true}
    ])

    :ets.new(@pipeline_offsprings_ets, [
      :public,
      # allows duplicates
      :bag,
      :named_table,
      {:read_concurrency, true}
    ])

    :ok
  end

  @spec get_span_and_pipeline(pid()) :: {:ok, OpenTelemetry.span_ctx(), pid()}
  def get_span_and_pipeline(pid) do
    [{^pid, {span_ctx, pipeline}}] = :ets.lookup(@pid_to_span_ets, pid)
    {:ok, span_ctx, pipeline}
  end

  @spec store_span_and_pipeline(OpenTelemetry.span_ctx(), pid()) :: :ok
  def store_span_and_pipeline(span_ctx, pipeline) do
    :ets.insert(@pid_to_span_ets, {self(), {span_ctx, pipeline}})
    :ok
  end

  def delete_span_and_pipeline(component_pid, span_ctx, pipeline) do
    :ets.delete(@pid_to_span_ets, {component_pid, {span_ctx, pipeline}})
  end

  def store_pipeline_offspring(pipeline) do
    :ets.insert(@pipeline_offsprings_ets, {pipeline, self()})
    :ok
  end

  def get_pipeline_offsprings(pipeline) do
    :ets.lookup(@pipeline_offsprings_ets, pipeline)
    |> Enum.map(fn {^pipeline, component} -> component end)
  end

  def delete_pipeline_offspring(pipeline, offspring) do
    :ets.delete(@pipeline_offsprings_ets, {pipeline, offspring})
  end
end
