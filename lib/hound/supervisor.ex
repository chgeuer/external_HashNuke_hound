defmodule Hound.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, [options])
  end

  @impl Supervisor
  def init([options]) do
    children = [
      %{id: Hound.ConnectionServer, start: {Hound.ConnectionServer, :start_link, [options]}},
      %{id: Hound.SessionServer, start: {Hound.SessionServer, :start_link, []}}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end