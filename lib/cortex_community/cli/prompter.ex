defmodule CortexCommunity.CLI.Prompter do
  @moduledoc """
  Interactive CLI prompts for the setup wizard.
  Provides a simple interface for user input similar to Clack/prompts.
  """

  @doc """
  Presents a selection menu and returns the chosen value.

  ## Examples

      iex> Prompter.select("Choose provider:", [
        {"Anthropic", :anthropic},
        {"OpenAI", :openai}
      ])
      :anthropic
  """
  def select(message, options) when is_list(options) do
    IO.puts("\n" <> IO.ANSI.white() <> message <> IO.ANSI.reset())

    options
    |> Enum.with_index(1)
    |> Enum.each(fn {{label, _value}, index} ->
      IO.puts("  #{IO.ANSI.cyan()}#{index}.#{IO.ANSI.reset()} #{label}")
    end)

    choice = get_number_input("\nSelect (1-#{length(options)}): ", 1, length(options))

    options
    |> Enum.at(choice - 1)
    |> elem(1)
  end

  @doc """
  Asks for text input.

  ## Examples

      iex> Prompter.text("Enter your API key:")
      "sk-ant-..."
  """
  def text(message) do
    IO.gets("\n" <> IO.ANSI.white() <> message <> IO.ANSI.reset() <> " ")
    |> String.trim()
  end

  @doc """
  Asks for confirmation (yes/no).

  ## Examples

      iex> Prompter.confirm("Continue?")
      true
  """
  def confirm(message, default \\ true) do
    hint = if default, do: " (Y/n)", else: " (y/N)"

    response =
      IO.gets(
        "\n" <> IO.ANSI.white() <> message <> IO.ANSI.cyan() <> hint <> IO.ANSI.reset() <> " "
      )
      |> String.trim()
      |> String.downcase()

    case response do
      "" -> default
      "y" -> true
      "yes" -> true
      "n" -> false
      "no" -> false
      _ -> confirm(message, default)
    end
  end

  @doc """
  Displays an informational note.
  """
  def note(message, title \\ nil) do
    if title do
      IO.puts("\n" <> IO.ANSI.cyan() <> "ℹ #{title}" <> IO.ANSI.reset())
    end

    IO.puts("  " <> message)
    IO.puts("")
  end

  # Private helpers

  defp get_number_input(prompt, min, max) do
    input = IO.gets(prompt) |> String.trim()

    case Integer.parse(input) do
      {num, ""} when num >= min and num <= max ->
        num

      _ ->
        IO.puts(
          IO.ANSI.red() <>
            "Invalid choice. Please enter a number between #{min} and #{max}." <> IO.ANSI.reset()
        )

        get_number_input(prompt, min, max)
    end
  end
end
