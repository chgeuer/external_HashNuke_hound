defmodule Hound.Browser.Edge do
  @moduledoc false

  @behaviour Hound.Browser

  def default_user_agent, do: :edge

  def default_capabilities(_ua), do: %{}
end
