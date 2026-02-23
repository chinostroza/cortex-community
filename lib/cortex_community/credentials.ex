defmodule CortexCommunity.Credentials do
  @moduledoc """
  Context module for managing user credentials.

  Handles encryption/decryption and database operations for user credentials.
  """

  import Ecto.Query
  alias CortexCommunity.Repo
  alias CortexCommunity.UserCredential

  @doc """
  Stores credentials for a user and provider.

  ## Examples

      iex> store_credentials("user_123", "anthropic_cli", %{
        type: :oauth,
        access_token: "...",
        refresh_token: "...",
        expires: 1234567890
      })
      {:ok, %UserCredential{}}
  """
  def store_credentials(user_id, provider, credentials_data) when is_map(credentials_data) do
    auth_type = determine_auth_type(credentials_data)
    encrypted_data = encrypt_credentials(credentials_data)

    attrs = %{
      user_id: user_id,
      provider: provider,
      auth_type: auth_type,
      encrypted_data: encrypted_data,
      expires_at: extract_expiry(credentials_data),
      is_active: true
    }

    # Upsert: update if exists, insert otherwise
    case Repo.get_by(UserCredential, user_id: user_id, provider: provider) do
      nil ->
        %UserCredential{}
        |> UserCredential.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> UserCredential.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Retrieves and decrypts credentials for a user and provider.
  """
  def get_credentials(user_id, provider) do
    credential =
      Repo.one(
        from c in UserCredential,
        where: c.user_id == ^user_id and c.provider == ^provider and c.is_active == true,
        order_by: [desc: c.inserted_at],
        limit: 1
      )

    case credential do
      nil ->
        {:error, :not_found}

      %UserCredential{} = cred ->
        if UserCredential.expired?(cred) do
          {:error, :expired}
        else
          # Mark as used
          cred
          |> UserCredential.mark_as_used()
          |> Repo.update()

          decrypted_data = decrypt_credentials(cred.encrypted_data)
          {:ok, Map.put(decrypted_data, :provider, provider)}
        end
    end
  end

  @doc """
  Lists all active credentials for a user.
  """
  def list_user_credentials(user_id) do
    UserCredential
    |> where([c], c.user_id == ^user_id and c.is_active == true)
    |> order_by([c], desc: c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Deletes credentials for a user and provider.
  """
  def delete_credentials(user_id, provider) do
    case Repo.get_by(UserCredential, user_id: user_id, provider: provider) do
      nil -> {:error, :not_found}
      credential -> Repo.delete(credential)
    end
  end

  # Private helpers

  defp determine_auth_type(%{type: :oauth}), do: "oauth"
  defp determine_auth_type(%{api_key: _}), do: "api_key"
  defp determine_auth_type(%{token: _}), do: "token"
  defp determine_auth_type(_), do: "token"

  defp extract_expiry(%{expires: expires}) when is_integer(expires) do
    DateTime.from_unix!(expires, :millisecond)
  end
  defp extract_expiry(_), do: nil

  defp encrypt_credentials(data) when is_map(data) do
    # TODO: Implement proper encryption
    # For now, just encode as JSON
    Jason.encode!(data)
  end

  defp decrypt_credentials(encrypted_data) when is_binary(encrypted_data) do
    # TODO: Implement proper decryption
    # For now, just decode JSON
    Jason.decode!(encrypted_data, keys: :atoms)
  end
end
