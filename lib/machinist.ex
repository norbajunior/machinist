defmodule Machinist do
  @moduledoc """
  Documentation for `Machinist`.
  """

  defmacro __using__(_) do
    quote do
      @__attr__ :state

      @behaviour Machinist.Transition

      import unquote(__MODULE__)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro from(state, to: new_state, event: event) do
    quote do
      @impl true
      def transit(%@__struct__{@__attr__ => unquote(state)} = resource, event: unquote(event)) do
        value = __set_new_state__(resource, unquote(new_state))

        {:ok, Map.put(resource, @__attr__, value)}
      end
    end
  end

  defmacro transitions(struct, [field: field], do: block) do
    quote do
      @__attr__ unquote(field)
      @__struct__ unquote(struct)

      unquote(block)
    end
  end

  defmacro transitions([field: field], do: block) do
    quote do
      @__attr__ unquote(field)
      @__struct__ __MODULE__

      unquote(block)
    end
  end

  defmacro transitions(struct, do: block) do
    quote do
      @__struct__ unquote(struct)

      unquote(block)
    end
  end

  defmacro transitions(do: block) do
    quote do
      @__struct__ __MODULE__

      unquote(block)
    end
  end

  defmacro __before_compile__(_) do
    quote do
      @impl true
      def transit(_resource, _opts) do
        {:error, :not_allowed}
      end

      defp __set_new_state__(resource, new_state)
           when is_function(new_state) do
        new_state.(resource)
      end

      defp __set_new_state__(_, new_state), do: new_state
    end
  end
end
