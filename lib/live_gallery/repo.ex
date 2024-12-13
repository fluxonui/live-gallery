defmodule LiveGallery.Repo do
  use Ecto.Repo,
    otp_app: :live_gallery,
    adapter: Ecto.Adapters.Postgres
end
