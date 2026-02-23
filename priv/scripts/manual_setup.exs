# Manual setup script for testing
alias CortexCommunity.{Users, Credentials, Repo}

IO.puts("\n🔧 Iniciando setup manual de Cortex...")

# Crear usuario
{:ok, user} = Users.create_user(%{username: "default", name: "Default User"})
IO.puts("\n✓ Usuario creado: #{user.username} (ID: #{user.id})")

# Crear API key
{:ok, api_key} = Users.create_api_key(user.id, %{name: "Test API Key"})
IO.puts("\n✓ API Key generado:")
IO.puts("  " <> IO.ANSI.bright() <> IO.ANSI.white() <> api_key.key <> IO.ANSI.reset())

# Guardar credenciales de prueba (simulando Claude Code CLI)
fake_creds = %{
  type: :oauth,
  access_token: "test_token_123",
  refresh_token: "refresh_123",
  expires: System.system_time(:millisecond) + 3_600_000  # 1 hora
}

{:ok, _cred} = Credentials.store_credentials(user.id, "anthropic_cli", fake_creds)
IO.puts("\n✓ Credenciales guardadas para: anthropic_cli")

IO.puts("\n" <> IO.ANSI.green() <> "═══════════════════════════════════════" <> IO.ANSI.reset())
IO.puts(IO.ANSI.green() <> "✓ Setup manual completado!" <> IO.ANSI.reset())
IO.puts(IO.ANSI.green() <> "═══════════════════════════════════════" <> IO.ANSI.reset())
IO.puts("\n" <> IO.ANSI.cyan() <> "Usa este API key para probar:" <> IO.ANSI.reset())
IO.puts("  Authorization: Bearer " <> api_key.key)
IO.puts("")

# Guardar API key en un archivo temporal para usarlo en las pruebas
File.write!("/tmp/cortex_api_key.txt", api_key.key)
IO.puts(IO.ANSI.yellow() <> "💾 API key guardado en: /tmp/cortex_api_key.txt" <> IO.ANSI.reset())
IO.puts("")
