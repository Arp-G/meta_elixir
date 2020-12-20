defmodule Loop do

  defmacro while(expression, do: block) do
    quote do
      try do

        # Use an infinite Stream to create an infinite loop
        for _ <- Stream.cycle([:ok]) do
          if unquote(expression) do
            unquote(block)
          else
            Loop.break # If the while condition is false thow to break out of the loop
          end
        end
      catch
        :break -> :ok  # Catch any breaks that was used in the loop
      end
    end
  end

  # This helps if user has used break in the code
  def break, do: throw :break
end
