defmodule Membrane.OpenTelemetry.Plugs.Launch do
  @moduledoc """
  Attaches OpenTelemetry spans describing events during components launch, since `handle_init` until `handle_end_of_stream`
  """

  alias Membrane.OpenTelemetry.Plugs.Launch.HandlerFunctions

  @all_callbacks [
                   Membrane.Pipeline,
                   Membrane.Bin,
                   Membrane.Element.Base,
                   Membrane.Element.WithInputPads,
                   Membrane.Element.WithOutputPads
                 ]
                 |> Enum.flat_map(fn module -> module.behaviour_info(:callbacks) end)
                 |> Keyword.keys()
                 |> Enum.uniq()
                 |> List.delete(:__struct__)

  @spec attach_events() :: :ok
  def attach_events() do
    __MODULE__.ETSWrapper.setup_ets_table()

    :telemetry.attach(
      {__MODULE__, :start_span},
      [:membrane, :handle_init, :start],
      &HandlerFunctions.start_span/4,
      nil
    )

    @all_callbacks
    |> Enum.each(fn callback ->
      :telemetry.attach(
        {__MODULE__, callback, :start},
        [:membrane, callback, :start],
        &HandlerFunctions.callback_start/4,
        nil
      )

      :telemetry.attach(
        {__MODULE__, callback, :stop},
        [:membrane, callback, :stop],
        &HandlerFunctions.callback_stop/4,
        nil
      )
    end)

    :telemetry.attach(
      {__MODULE__, :end_span},
      [:membrane, :handle_start_of_stream, :stop],
      &HandlerFunctions.end_span/4,
      nil
    )
  end
end
