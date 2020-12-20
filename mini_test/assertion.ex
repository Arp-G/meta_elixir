defmodule Assertion do

  # This __using__/1 macro is called when our Assertion module is used
  defmacro __using__(_options) do
    quote do
      # import Assertion
      import unquote(__MODULE__)

      # This is used to create module attributes, the `accumulate: true` option
      # ensures that several calls to the same attribute will accumulate instead of overriding the previous one.
      # here, @tests will hold multiple user sepcified tests like...
      # [{:"integers can be multiplied and divided", "integers can be multiplied and divided"}, {:integers can be multiplied and divided, "integers can be multiplied and divided"}]
      # https://hexdocs.pm/elixir/Module.html#register_attribute/3
      Module.register_attribute(__MODULE__, :tests, accumulate: true)


      # @before_compile is hook to notify the compiler that an extra step is required just before compilation is finished.
      # Accepts a module or a {module, function_or_macro_name} tuple. When just a module is provided, the function/macro is assumed to be __before_compile__/1.
      # Here, Assert.__before_compile__/1 is invoked just before MathTest is finished being compiled.
      # We use this hook here because we want to generate and expand run functions for all the tests
      # the user specified AFTER all the tests are accumulated in the model attribute @tests
      # https://hexdocs.pm/elixir/Module.html#module-before_compile-1
      @before_compile unquote(__MODULE__)
    end
  end

  # This macro is executed by the @before_compile hook after all the tests are accumulted in @tests
  # that is it is called after all thes `test/2` macro calls are over and all tests are registered in @test
  defmacro __before_compile__(_env) do
    quote do
      # Inject a run method to run all tests registered in @tests
      def run, do: Assertion.Test.run(@tests, __MODULE__)
    end
  end

  # This macro is called whenever user uses `test "description...` it accepts a user specified test description and block to execute
  defmacro test(description, do: test_block) do
    # Creates an atom from the test description like :"integers can be multiplied and divided"
    test_func = String.to_atom(description)

    quote do
      # ADD TEST TO THE LIST OF TESTS TO RUN
      # Add a new test item to the module attribute @tests
      # like {:"integers can be multiplied and divided", "integers can be multiplied and divided"}
      @tests {unquote(test_func), unquote(description)}

      # CREATE FUNCTION FOR TEST
      # inject a new function having a function name same as what was passed as description of the test
      # Also, inject the block of code to be executed as the test inside the functions body
      def unquote(test_func)(), do: unquote(test_block)
    end
  end

  # Define an assert macro which pattern matches out the operator and lhs , rhs of the assertion
  defmacro assert({operator, _, [lhs, rhs]}) do

    # Use :bind_quoted option on quote to avoid multiple unquote calls like: Assertion.Test.assert(unquote(operator), unquote(lhs), unquote(rhs))
    quote bind_quoted: [operator: operator, lhs: lhs, rhs: rhs] do
      # Call assert function
      Assertion.Test.assert(operator, lhs, rhs)
    end
  end
end

# Defines deffirent assert functions and uses mattern matching and guard clauses to
# invoke the correct assertion based on the operators and sucess/faliure case.
defmodule Assertion.Test do
  # Called from the `__before_compile__` macro with all registered tests
  # Called with [{:test_func_name, "test description", Assertion}]
  def run(tests, module) do

    # Iterate over every test function that was inject looking like {:"integers can be multiplied and divided", "integers can be multiplied and divided"}
    # Invokes each test using Kernel.apply/3 which invokes a given function of a module with the list of arguments args
    # It also prints some stuff depending on wether the test failed or passed
    Enum.each(tests, fn {test_func, description} ->
      case apply(module, test_func, []) do
        :ok ->
          IO.write(".")

        {:fail, reason} ->
          IO.puts("""
            -
          ===============================================
            40 FAILURE: #{description}
          ===============================================
          #{reason}
          """)
      end
    end)
  end

  def assert(:==, lhs, rhs) when lhs == rhs do
    :ok
  end

  def assert(:==, lhs, rhs) do
    {:fail,
     """
     Expected: #{lhs}
     to be equal to: #{rhs}
     """}
  end

  def assert(:>, lhs, rhs) when lhs > rhs do
    :ok
  end

  def assert(:>, lhs, rhs) do
    {:fail,
     """
     Expected: #{lhs}
        to be greater than: #{rhs}
     """}
  end
end

# Simple Driver Code
# Execute using `MathTest.run()`
defmodule MathTest do
  use Assertion

  test "integers can be added and subtracted" do
    assert 2 + 3 == 5
    assert 5 - 5 == 10
  end

  test "integers can be multiplied and divided" do
    assert 5 * 5 == 25
    assert 10 / 2 == 5
  end
end
