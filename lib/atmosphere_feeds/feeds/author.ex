defmodule AtmosphereFeeds.Feeds.Author do
  use Ecto.Schema
  import Ecto.Changeset

  schema "authors" do
    field :did, :string
    field :handle, :string
    field :display_name, :string
    field :avatar_url, :string

    has_many :publications, AtmosphereFeeds.Feeds.Publication
    has_many :documents, AtmosphereFeeds.Feeds.Document

    timestamps()
  end

  def changeset(author, attrs) do
    author
    |> cast(attrs, [:did, :handle, :display_name, :avatar_url])
    |> validate_required([:did])
    |> unique_constraint(:did)
  end
end
