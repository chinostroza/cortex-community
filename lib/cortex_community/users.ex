defmodule CortexCommunity.Users do
  @moduledoc """
  Context module for managing Cortex users and API keys.
  """

  import Ecto.Query
  alias CortexCommunity.Repo
  alias CortexCommunity.CortexUser
  alias CortexCommunity.CortexApiKey

  # User operations

  @doc """
  Creates a new Cortex user.

  ## Examples

      iex> create_user(%{username: "my_cortex", email: "user@example.com"})
      {:ok, %CortexUser{}}
  """
  def create_user(attrs) do
    %CortexUser{}
    |> CortexUser.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a user by username.
  """
  def get_user_by_username(username) do
    Repo.get_by(CortexUser, username: username)
  end

  @doc """
  Gets or creates a default user for setup.

  Used during `mix cortex.setup` to ensure there's a user to associate credentials with.
  """
  def get_or_create_default_user do
    username = "default"

    case get_user_by_username(username) do
      nil ->
        create_user(%{
          username: username,
          name: "Default Cortex User"
        })

      user ->
        {:ok, user}
    end
  end

  @doc """
  Lists all users.
  """
  def list_users do
    Repo.all(CortexUser)
  end

  # API Key operations

  @doc """
  Creates a new API key for a user.

  ## Examples

      iex> create_api_key(user_id, %{name: "Allisbox Production"})
      {:ok, %CortexApiKey{key: "ctx_..."}}
  """
  def create_api_key(user_id, attrs \\ %{}) do
    attrs_with_user = Map.put(attrs, :user_id, user_id)

    CortexApiKey.create_changeset(attrs_with_user)
    |> Repo.insert()
  end

  @doc """
  Finds a user by their API key.

  Returns `{:ok, user}` if found and valid, `{:error, reason}` otherwise.
  """
  def authenticate_by_api_key(api_key_string) when is_binary(api_key_string) do
    query =
      from k in CortexApiKey,
        where: k.key == ^api_key_string and k.is_active == true,
        preload: [:user]

    case Repo.one(query) do
      nil ->
        {:error, :invalid_api_key}

      api_key ->
        if CortexApiKey.valid?(api_key) do
          # Mark as used
          api_key
          |> CortexApiKey.mark_as_used()
          |> Repo.update()

          {:ok, api_key.user}
        else
          {:error, :expired_api_key}
        end
    end
  end

  @doc """
  Gets the existing active API key for a user, or creates one if none exists.

  Keys without expiry are preferred. This ensures the same key is reused
  across server restarts instead of generating a new one each time.
  """
  def get_or_create_api_key(user_id, attrs \\ %{}) do
    query =
      from k in CortexApiKey,
        where: k.user_id == ^user_id and k.is_active == true and is_nil(k.expires_at),
        order_by: [asc: k.inserted_at],
        limit: 1

    case Repo.one(query) do
      nil -> create_api_key(user_id, attrs)
      existing -> {:ok, existing}
    end
  end

  @doc """
  Lists all API keys for a user.
  """
  def list_user_api_keys(user_id) do
    CortexApiKey
    |> where([k], k.user_id == ^user_id)
    |> order_by([k], desc: k.inserted_at)
    |> Repo.all()
  end

  @doc """
  Revokes an API key (sets is_active to false).
  """
  def revoke_api_key(api_key_id) do
    case Repo.get(CortexApiKey, api_key_id) do
      nil ->
        {:error, :not_found}

      api_key ->
        api_key
        |> Ecto.Changeset.change(is_active: false)
        |> Repo.update()
    end
  end

  @doc """
  Generates a preview of an API key (shows first/last chars only).

  ## Examples

      iex> preview_api_key("ctx_abc123def456ghi789")
      "ctx_abc...i789"
  """
  def preview_api_key(key) when is_binary(key) do
    if String.length(key) > 15 do
      prefix = String.slice(key, 0, 7)
      suffix = String.slice(key, -4, 4)
      "#{prefix}...#{suffix}"
    else
      key
    end
  end
end
