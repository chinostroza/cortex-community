defmodule Mix.Tasks.Cortex.Setup do
  @moduledoc """
  Interactive setup wizard for Cortex Community.

  Similar to OpenClaw's onboarding, this guides users through:
  - Configuring AI providers
  - Setting up authentication (Claude Code CLI, API keys, etc.)
  - Database initialization

  ## Usage

      mix cortex.setup
      mix cortex.setup --provider=anthropic
  """
  use Mix.Task

  @shortdoc "Interactive setup wizard for Cortex"

  alias CortexCommunity.CLI.Prompter
  alias CortexCommunity.Auth.ClaudeCliReader
  alias CortexCommunity.Credentials
  alias CortexCommunity.Users

  # State to track generated API key during setup
  @api_key_agent_name __MODULE__.ApiKeyAgent

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    opts = parse_args(args)

    IO.puts("\n")
    IO.puts(IO.ANSI.cyan() <> "╔═══════════════════════════════════════╗" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.cyan() <> "║   " <> IO.ANSI.white() <> "Cortex Community Setup Wizard" <> IO.ANSI.cyan() <> "    ║" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.cyan() <> "╚═══════════════════════════════════════╝" <> IO.ANSI.reset())
    IO.puts("\n")

    if opts[:provider] do
      setup_provider(opts[:provider])
    else
      interactive_setup()
    end
  end

  defp parse_args(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [provider: :string],
      aliases: [p: :provider]
    )
    opts
  end

  defp interactive_setup do
    IO.puts("Welcome to Cortex! Let's get you set up.\n")

    mode = Prompter.select(
      "Setup mode:",
      [
        {"QuickStart (Recommended)", :quickstart},
        {"Manual Configuration", :manual}
      ]
    )

    case mode do
      :quickstart -> quickstart_flow()
      :manual -> manual_flow()
    end
  end

  defp quickstart_flow do
    IO.puts(IO.ANSI.green() <> "\n✓ QuickStart selected" <> IO.ANSI.reset())
    IO.puts("We'll configure the essentials and you can customize later.\n")

    provider = Prompter.select(
      "Select your primary AI provider:",
      [
        {"Anthropic (Claude Code CLI) - Reuses existing Claude Code auth", :anthropic_cli},
        {"Anthropic (API Key)", :anthropic_api},
        {"OpenAI", :openai},
        {"Google Gemini", :google},
        {"Groq", :groq},
        {"Skip for now", :skip}
      ]
    )

    case provider do
      :anthropic_cli -> setup_anthropic_cli()
      :anthropic_api -> setup_anthropic_api()
      :openai -> setup_openai()
      :google -> setup_google()
      :groq -> setup_groq()
      :skip -> skip_provider_setup()
    end

    finalize_setup()
  end

  defp setup_anthropic_cli do
    IO.puts(IO.ANSI.cyan() <> "\n→ Anthropic (Claude Code CLI)" <> IO.ANSI.reset())
    IO.puts("Looking for Claude Code credentials...\n")

    case ClaudeCliReader.read_credentials() do
      {:ok, credentials} ->
        IO.puts(IO.ANSI.green() <> "✓ Found Claude Code credentials!" <> IO.ANSI.reset())
        IO.puts("  Token type: #{credentials.type}")
        IO.puts("  Expires: #{format_timestamp(credentials.expires)}")

        if Prompter.confirm("\nUse these credentials for Cortex?") do
          save_credentials("anthropic_cli", credentials)
          IO.puts(IO.ANSI.green() <> "✓ Credentials saved!" <> IO.ANSI.reset())
        else
          IO.puts("Skipping...")
        end

      {:error, :not_found} ->
        IO.puts(IO.ANSI.yellow() <> "⚠ No Claude Code credentials found" <> IO.ANSI.reset())
        IO.puts("\nTo use Claude Code CLI authentication:")
        IO.puts("  1. Install Claude Code: https://claude.ai/code")
        IO.puts("  2. Run: claude setup-token")
        IO.puts("  3. Re-run: mix cortex.setup")
        IO.puts("\nWould you like to use an API key instead?")

        if Prompter.confirm("Switch to API key setup?") do
          setup_anthropic_api()
        end

      {:error, reason} ->
        IO.puts(IO.ANSI.red() <> "✗ Error reading credentials: #{inspect(reason)}" <> IO.ANSI.reset())
    end
  end

  defp setup_anthropic_api do
    IO.puts(IO.ANSI.cyan() <> "\n→ Anthropic API Key" <> IO.ANSI.reset())
    IO.puts("Get your API key from: https://console.anthropic.com/\n")

    api_key = Prompter.text("Enter your Anthropic API key:")

    if String.starts_with?(api_key, "sk-ant-") do
      save_credentials("anthropic_api", %{api_key: api_key})
      IO.puts(IO.ANSI.green() <> "✓ API key saved!" <> IO.ANSI.reset())
    else
      IO.puts(IO.ANSI.yellow() <> "⚠ API key format looks incorrect" <> IO.ANSI.reset())
      if Prompter.confirm("Save anyway?") do
        save_credentials("anthropic_api", %{api_key: api_key})
      end
    end
  end

  defp setup_openai do
    IO.puts(IO.ANSI.cyan() <> "\n→ OpenAI" <> IO.ANSI.reset())
    api_key = Prompter.text("Enter your OpenAI API key:")
    save_credentials("openai", %{api_key: api_key})
    IO.puts(IO.ANSI.green() <> "✓ Saved!" <> IO.ANSI.reset())
  end

  defp setup_google do
    IO.puts(IO.ANSI.cyan() <> "\n→ Google Gemini" <> IO.ANSI.reset())
    api_key = Prompter.text("Enter your Google AI API key:")
    save_credentials("google", %{api_key: api_key})
    IO.puts(IO.ANSI.green() <> "✓ Saved!" <> IO.ANSI.reset())
  end

  defp setup_groq do
    IO.puts(IO.ANSI.cyan() <> "\n→ Groq" <> IO.ANSI.reset())
    api_key = Prompter.text("Enter your Groq API key:")
    save_credentials("groq", %{api_key: api_key})
    IO.puts(IO.ANSI.green() <> "✓ Saved!" <> IO.ANSI.reset())
  end

  defp skip_provider_setup do
    IO.puts(IO.ANSI.yellow() <> "\n⊘ Skipping provider setup" <> IO.ANSI.reset())
    IO.puts("You can configure providers later with:")
    IO.puts("  mix cortex.setup --provider=anthropic")
  end

  defp manual_flow do
    IO.puts("\nManual configuration coming soon...")
    IO.puts("For now, please use QuickStart mode.")
  end

  defp save_credentials(provider, credentials) do
    # Get or create default user
    {:ok, user} = Users.get_or_create_default_user()

    # Save credentials for this user
    case Credentials.store_credentials(user.id, provider, credentials) do
      {:ok, _credential} ->
        IO.puts(IO.ANSI.green() <> "\n✓ Credentials saved to database!" <> IO.ANSI.reset())

        # Generate API key for the user (only once during setup)
        ensure_api_key_generated(user)

      {:error, changeset} ->
        IO.puts(IO.ANSI.red() <> "\n✗ Error saving credentials:" <> IO.ANSI.reset())
        IO.inspect(changeset.errors)
    end
  end

  defp ensure_api_key_generated(user) do
    # Check if we already generated an API key in this session
    existing_keys = Users.list_user_api_keys(user.id)

    if Enum.empty?(existing_keys) do
      # No API keys yet - generate one
      case Users.create_api_key(user.id, %{name: "Setup Wizard Key"}) do
        {:ok, api_key} ->
          # Store in process dictionary to display later
          Process.put(@api_key_agent_name, api_key.key)
          IO.puts(IO.ANSI.cyan() <> "✓ Generated Cortex API key" <> IO.ANSI.reset())

        {:error, _changeset} ->
          IO.puts(IO.ANSI.yellow() <> "⚠ Could not generate API key" <> IO.ANSI.reset())
      end
    else
      # API key already exists - store the first one
      Process.put(@api_key_agent_name, List.first(existing_keys).key)
    end
  end

  defp finalize_setup do
    IO.puts("\n")
    IO.puts(IO.ANSI.green() <> "═══════════════════════════════════════" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.green() <> "✓ Setup complete!" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.green() <> "═══════════════════════════════════════" <> IO.ANSI.reset())

    # Display API key if generated
    case Process.get(@api_key_agent_name) do
      nil ->
        :ok

      api_key ->
        IO.puts("\n" <> IO.ANSI.cyan() <> "Your Cortex API Key:" <> IO.ANSI.reset())
        IO.puts(IO.ANSI.white() <> IO.ANSI.bright() <> "  #{api_key}" <> IO.ANSI.reset())
        IO.puts("\n" <> IO.ANSI.yellow() <> "⚠ Save this key somewhere safe - you won't see it again!" <> IO.ANSI.reset())
        IO.puts("\nUse this key in your client applications (like Allisbox):")
        IO.puts("  Authorization: Bearer #{api_key}")
    end

    IO.puts("\nYou can now start Cortex:")
    IO.puts(IO.ANSI.cyan() <> "  mix server" <> IO.ANSI.reset())
    IO.puts("\nOr configure more providers:")
    IO.puts(IO.ANSI.cyan() <> "  mix cortex.setup --provider=<name>" <> IO.ANSI.reset())
    IO.puts("\n")
  end

  defp setup_provider(provider) do
    case provider do
      "anthropic" -> setup_anthropic_cli()
      "openai" -> setup_openai()
      "google" -> setup_google()
      "groq" -> setup_groq()
      _ -> IO.puts("Unknown provider: #{provider}")
    end
  end

  defp format_timestamp(unix_ms) when is_integer(unix_ms) do
    DateTime.from_unix!(unix_ms, :millisecond)
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S")
  end
  defp format_timestamp(_), do: "Unknown"
end
