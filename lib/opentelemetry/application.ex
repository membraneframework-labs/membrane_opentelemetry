defmodule Membrane.OpenTelemetry.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    :ok = Membrane.OpenTelemetry.Utils.create_ets_tables()

    children = []
    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end
