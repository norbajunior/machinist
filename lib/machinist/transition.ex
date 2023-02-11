defmodule Machinist.Transition do
  @moduledoc """
  `Machinist.Transition` module behaviour
  """
  @callback transit(struct(), event: String.t()) ::
              {:ok, struct()} | {:error, :not_allowed | String.t()}
end
