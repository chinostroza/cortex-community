defmodule CortexCommunity.CortexUser do
  @moduledoc """
  Schema for Cortex users (local users of the Cortex gateway).

  Each user can have:
  - Multiple API keys (for authenticating requests from client apps)
  - Multiple credentials (OAuth tokens, API keys for AI providers)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "cortex_users" do
    field(:username, :string)
    field(:email, :string)
    field(:name, :string)

    has_many(:api_keys, CortexCommunity.CortexApiKey, foreign_key: :user_id)
    has_many(:credentials, CortexCommunity.UserCredential, foreign_key: :user_id)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating a user.
  """
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :name])
    |> validate_required([:username])
    |> validate_format(:email, ~r/@/, message: "must be a valid email")
    |> unique_constraint(:username)
  end

  @doc """
  Changeset for creating a new user during setup.
  """
  def setup_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:username, :email, :name])
    |> validate_required([:username])
    |> put_change(:username, attrs[:username] || generate_username())
    |> unique_constraint(:username)
  end

  # Generate a default username if not provided
  defp generate_username do
    "cortex_user_#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"
  end
end
