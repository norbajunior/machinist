defmodule Machinist.Transition do
  @callback transit(struct(), event: String.t()) ::
              {:ok, struct()} | {:error, :not_allowed}
end
