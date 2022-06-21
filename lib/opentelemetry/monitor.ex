defmodule Membrane.OpenTelemetry.Monitor do
  @moduledoc false

  require OpenTelemetry.Tracer

  alias Membrane.OpenTelemetry.ETSUtils

  @spec start(pid() | atom()) :: pid()
  def start(observed_process) do
    Process.spawn(__MODULE__, :run, [observed_process], [])
  end

  @spec run(pid()) :: :ok
  def run(observed_process) do
    Process.monitor(observed_process)

    receive do
      {:DOWN, _ref, _process, ^observed_process, _reason} ->
        ETSUtils.get_process_spans(observed_process)
        |> Enum.each(fn {_pid, span} ->
          OpenTelemetry.Tracer.set_current_span(span)
          OpenTelemetry.Tracer.end_span()
        end)

        ETSUtils.delete_process_spans(observed_process)
    end

    :ok
  end
end
