defmodule CortexCommunity.UsersBehaviour do
  @moduledoc """
  Defines the contract for user and API key operations, enabling Mox-based mocking in tests.
  """

  @callback authenticate_by_api_key(api_key :: binary()) ::
              {:ok, CortexCommunity.CortexUser.t()}
              | {:error, :not_found | :invalid_api_key | :expired_api_key}
end
