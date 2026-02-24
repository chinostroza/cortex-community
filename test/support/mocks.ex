defmodule CortexCommunity.Mocks do
  @moduledoc """
  Defines all Mox mocks for unit testing.

  Mock responses are based on actual responses captured from the live system
  to ensure tests reflect realistic behaviour.
  """

  # CortexCore mock — AI providers (Gemini, Groq) and worker registry
  Mox.defmock(CortexCore.Mock, for: CortexCore.Behaviour)

  # Users mock — API key authentication
  Mox.defmock(CortexCommunity.Users.Mock, for: CortexCommunity.UsersBehaviour)
end
