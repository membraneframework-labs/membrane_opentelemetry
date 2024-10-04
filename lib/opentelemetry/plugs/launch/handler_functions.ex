defmodule Membrane.OpenTelemetry.Plugs.Launch.HandlerFunctions do
  @moduledoc false
  require Membrane.OpenTelemetry

  alias Membrane.OpenTelemetry.Plugs.Launch.ETSWrapper

  @span_id "component_launch"
  @pdict_key_span_alive? :__membrane_opentelemetry_lanuch_span_alive?

  @spec pipeline_monitor(pid()) :: :ok
  def pipeline_monitor(pipeline) do
    ref = Process.monitor(pipline)

    receive do
      {:DOWN, ^ref, _process, _pid, _reason} -> cleanup_pipeline(pipeline)
    end

    :ok
  end

  defp cleanup_pipeline(pipeline) do
    ETSWrapper.get_pipeline_offsprings(pipeline)
    |> Enum.each(fn offspring ->
      {:ok, span_ctx, ^pipline} = ETSWrapper.get_span_and_pipeline(offspring)
      ETSWrapper.delete_span_and_pipeline(offspring, span_ctx, pipeline)
      ETSWrapper.delete_pipeline_offspring(pipeline, offspring)
    end)
  end

  defp do_start_span(component_type, component_state)

  defp do_start_span(:pipeline) do
    Membrane.OpenTelemetry.start_span(@span_id)
    Process.put(@pdict_key_span_alive?, true)

    pipeline = self()

    Membrane.OpenTelemetry.get_span(@span_id)
    |> ETSWrapper.store_span_and_pipeline(pipline)

    Task.start(__MODULE__, :pipeline_monitor, [pipeline])
  end

  defp do_start_span(:bin) do
    {:ok, parent_span_ctx, pipeline} = ETSWrapper.get_span_and_pipelne(component_state.parent_pid)
    Membrane.OpenTelemetry.start_span(@span_id, parent_span: parent_span_ctx)
    Process.put(@pdict_key_span_alive?, true)

    Membrane.OpenTelemetry.get_span(@span_id)
    |> ETSWrapper.store_span_and_pipeline(pipeline)

    ETSWrapper.store_pipeline_offspring(pipeline)
  end

  defp do_start_span(:element, component_state) do
    {:ok, parent_span_ctx, pipeline} = ETSWrapper.get_span_and_pipelne(component_state.parent_pid)
    Membrane.OpenTelemetry.start_span(@span_id, parent_span: parent_span_ctx)
    Process.put(@pdict_key_span_alive?, true)
  end

  def end_span(_name, _measurements, _metadata, _config) do
    Membrane.OpenTelemetry.end_span(@span_id)
    Process.put(@pdict_key_span_alive?, false)
  end

  def callback_start([:membrane, _callback, :start] = name, _measurements, _metadata, _config) do
    if Process.get(@pdict_key_span_alive, false) do
      event_name = name |> Enum.map_join("_", &Atom.to_string/1)
      Membrane.OpenTelemetry.add_event(@span_id, event_name)
    end
  end

  # @def callback_stop(:opentelemetry)
  def callback_stop(
        [:membrane, _callback, :stop] = name,
        %{duration: duration},
        _metadata,
        _config
      ) do
    if Process.get(@pdict_key_span_alive, false) do
      event_name = name |> Enum.map_join("_", &Atom.to_string/1)
      Membrane.OpenTelemetry.add_event(@span_id, event_name, duration: duration)
    end
  end
end
