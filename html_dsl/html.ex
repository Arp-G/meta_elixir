# An html DSL made using macros in elixir, No runtime penalty as complete macro is replaced by its corresponding html string at compile time.
# Here we traverse the AST using Macro.postwalk/2 and pattern match out different parts of the macros AST
# while creating its corresponding html string in a buffer maintained as an Agent genserver state.
# The Agent genserver acts as a buffer and  is required to preserve the created html string in its state as we recursively expand the macros.
defmodule Html do
  # @external_resource is an accumulated attribute, any number of resources can be registered on a single module.
  # Here, we keep the file path with all html tags here
  @external_resource tags_path = Path.join([__DIR__, "tags.txt"])

  # Load all the html tags in the external file as an array of atomes in @tags
  # Used in postwalk/1 to ensure the user given tags are among valid html tags
	@tags (for line <- File.stream!(tags_path, [], :line) do
		line |> String.trim |> String.to_atom
  end)

  # Top level wrapper macro named "markup" where the main html dsl macro block is passed
  # A new buffer is started for every markup macro call
  defmacro markup(do: block) do
    quote do
      # Start_buffer starts a new agent genserver to store created html string, it returns {:ok, <PID>}
      # Here we use `var!(buffer, Html)` to access the PID in the `buffer` varaible in the `Html` modules context.
      # This means `var!(buffer, Html) will give us the same `buffer` variable for the Html context whenever it is accessed.
      {:ok, var!(buffer, Html)} = start_buffer([])

      # Macro.postwalk/2 performs a depth-first, post-order traversal of quoted expressions.
      # This means we traverse from the most nested node outwards until the whole AST is covered

      # Here while traversing the AST we call `postwalk/1` to pattern match out various AST patterns
      # and form the html string in the buffer (Agent genserver)
      unquote(Macro.postwalk(block, &postwalk/1))

      # Return the create html string in the buffer
      result = render(var!(buffer, Html))

      # Stop the Agent once macro axpansion is complete
      :ok = stop_buffer(var!(buffer, Html))

      # return resulting html string
			result
    end
  end

  # tag/2 macro for tags without a "do" block
	defmacro tag(name, attrs \\ []) do
		{inner, attrs} = Keyword.pop(attrs, :do) # Pop any "do" block passed as attributes and call tag/3
		quote do: tag(unquote(name), unquote(attrs), do: unquote(inner))
  end

  # tag/3 macro for expanding tags
	defmacro tag(name, attrs, do: inner) do
		quote do
			put_buffer var!(buffer, Html), open_tag(unquote_splicing([name, attrs])) # Put open tag in buffer, unquote_splicing/1 unquotes list of args same as open_tag(unquote(name), unquote(attrs))
			unquote(postwalk(inner))                                                 # Expand and put inner contents of the tag in buffer
			put_buffer var!(buffer, Html), "</#{unquote(name)}>"                     # Put closing tag in buffer
		end
  end

  # For text tags, places the text contents in buffer
	defmacro text(string) do
		quote do: put_buffer(var!(buffer, Html), to_string(unquote(string)))
  end

  # While traversing the AST using Macro.postwalk/2, we call `postwalk/1` to pattern match out various AST patterns

  # If AST contains "text" node then put the text contents in buffer
	def postwalk({:text, _meta, [string]}) do
		quote do: put_buffer(var!(buffer, Html), to_string(unquote(string)))
  end

  # If AST contains a tag with a block and no attributes then call the tag/2 macro to put relevant contents in buffer
	def postwalk({tag_name, _meta, [[do: inner]]}) when tag_name in @tags do
		quote do: tag(unquote(tag_name), [], do: unquote(inner))
  end

  # If AST contains a tag with a block and additional attributes then call the tag/2 macro
  # along with unqouted attributes, to put relevant contents in buffer
	def postwalk({tag_name, _meta, [attrs, [do: inner]]}) when tag_name in @tags do
		quote do: tag(unquote(tag_name), unquote(attrs), do: unquote(inner))
  end

  # Return AST if no other previous patterns match
  def postwalk(ast), do: ast

  # Create Open tag string
  def open_tag(name, []), do: "<#{name}>"

  # Create Open tag string with attributes
	def open_tag(name, attrs) do
		attr_html = for {key, val} <- attrs, into: "", do: " #{key}=\"#{val}\""
		"<#{name}#{attr_html}>"
  end

  # Start an Agent which will act as a buffer to create and preserve the html string as we expand macros
  def start_buffer(state), do: Agent.start_link(fn -> state end)

  # Stop buffer
  def stop_buffer(buff), do: Agent.stop(buff)

  # Agent.update takes an anonymous function which accepts the state and returns new state
  # Here, we accept the old state list and append the new item in the list in the anonymous function to Agent.update lke `&[content | &1]`
  # We return the new appended list as the new state of the Agent
  def put_buffer(buff, content), do: Agent.update(buff, &[content | &1])

  # Render the generated html string, reverse buffer state list and join state items to form html string
	def render(buff), do: Agent.get(buff, &(&1)) |> Enum.reverse |> Enum.join("")
end

# Example template using the above html dsl
# Run in IEX using: c("html.ex"); Template.render
# Rendered HTML:
# <div id="main">
#   <h1 class="title">Welcome!</h1>
# </div>
# <div class="row">
#   <div>
#     <p>Hello</p>
#   </div>
# </div>
defmodule Template do
	import Html
	def render do
		markup do
			div id: "main" do
				h1 class: "title" do
					text "Welcome!"
				end
			end
			div class: "row" do
				div do
					p do: text "Hello"
				end
			end
		end
	end
end
