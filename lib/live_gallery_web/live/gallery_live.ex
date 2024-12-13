defmodule LiveGalleryWeb.GalleryLive do
  use LiveGalleryWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h1>Hello Gallery</h1>
    """
  end
end
