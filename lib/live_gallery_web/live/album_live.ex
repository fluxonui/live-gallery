defmodule LiveGalleryWeb.AlbumLive do
  use LiveGalleryWeb, :live_view
  alias LiveGalleryWeb.Uploader

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:album, %{name: "Best of 2024", access: "private"})
     |> assign(:album_form, to_form(%{"name" => "Best of 2024", "access" => "private"}))
     |> assign(:global_progress, 0)
     |> assign(:time_remaining, nil)
     |> assign(:upload_start_time, nil)
     |> assign(:total_upload_size, 0)
     |> allow_upload(:photos,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 10,
       auto_upload: true,
       external: &presign_entry/2,
       progress: &handle_progress/3
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex h-full dark:bg-zinc-900" phx-drop-target={@uploads.photos.ref}>
      <div class="flex-1 p-8">
        <div class="flex items-center justify-between">
          <h1 class="text-2xl font-bold flex items-center gap-x-2 dark:text-white">
            <span class="font-serif">{@album.name}</span>
            <.badge :if={@album.access == "private"} class="px-1.5 py-1">
              <.icon name="hero-lock-closed-solid" class="icon" /> Private
            </.badge>
            <.badge :if={@album.access == "public"} color="yellow" class="px-1.5 py-1">
              <.icon name="hero-globe-americas-solid" class="icon" /> Public
            </.badge>
          </h1>

          <.button phx-click={Fluxon.open_dialog("album-settings")}>
            <.icon name="hero-cog-6-tooth icon" /> Settings
          </.button>
        </div>

        <.upload_progress
          progress={@global_progress}
          total_entries={length(@uploads.photos.entries)}
          completed_entries={length(Enum.filter(@uploads.photos.entries, & &1.done?))}
          time_remaining={@time_remaining}
        />

        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4 mt-10">
          <form class="relative aspect-square" phx-change="validate" phx-submit="upload-photos">
            <.live_file_input upload={@uploads.photos} class="absolute inset-0 w-full h-full opacity-0 cursor-pointer peer" />
            <div class="aspect-square flex items-center flex-col px-6 text-center justify-center border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-zinc-800 transition-colors peer-hover:border-gray-400 dark:peer-hover:border-gray-500">
              <.icon name="hero-camera" class="size-9 text-gray-300 dark:text-gray-500 pointer-events-none" />
              <span class="font-medium mt-2 dark:text-white">Select images</span>
              <p class="text-sm text-gray-500 dark:text-gray-400">or drag photos from your computer</p>
            </div>
          </form>

          <div :for={entry <- @uploads.photos.entries} class="overflow-hidden rounded-lg relative">
            <figure class="aspect-square">
              <.live_img_preview entry={entry} class="w-full h-full object-cover" />
            </figure>

            <div :if={not entry.done?} class="flex items-center justify-center absolute inset-0 m-auto">
              <.circular_progress progress={entry.progress} class="w-16 h-16" />
            </div>

            <p :for={err <- upload_errors(@uploads.photos, entry)} class="alert alert-danger">
              {Uploader.error_to_string(err)}
            </p>
          </div>
        </div>
      </div>
    </div>

    <.sheet
      placement="right"
      id="album-settings"
      class="max-w-sm w-full border-l dark:border-zinc-700 h-full p-10 dark:bg-zinc-900"
    >
      <h2 class="text-xl font-bold dark:text-white">Settings</h2>

      <.form :let={f} for={@album_form} phx-submit="save-album-name" class="mt-6">
        <h2 class="text-lg font-semibold font-serif dark:text-white">Album name</h2>
        <div class="flex gap-x-2 mt-1">
          <div class="w-full"><.input field={f[:name]} /></div>
          <.button variant="solid">Save</.button>
        </div>
      </.form>

      <.form :let={f} for={@album_form} phx-change="update-album-access" class="mt-6">
        <h2 class="text-lg font-semibold dark:text-white">Access</h2>
        <p class="text-sm text-gray-500 dark:text-gray-400">Control who can view and download your photos.</p>

        <div class="flex gap-x-2 mt-4">
          <.radio_group field={f[:access]}>
            <:radio value="public" label="Public" description="Anyone can view and download your photos." />
            <:radio value="private" label="Private" description="Only you can view and download your photos." />
          </.radio_group>
        </div>
      </.form>
    </.sheet>
    """
  end

  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("save-album-name", %{"name" => name}, socket) do
    {:noreply, socket |> assign(:album, %{socket.assigns.album | name: name})}
  end

  def handle_event("update-album-access", %{"access" => access}, socket) do
    {:noreply, socket |> assign(:album, %{socket.assigns.album | access: access})}
  end

  defp presign_entry(entry, socket) do
    {:ok, presigned_data} = Uploader.presign_upload(entry)
    {:ok, presigned_data, socket}
  end

  def handle_progress(:photos, _entry, socket) do
    socket =
      if is_nil(socket.assigns.upload_start_time) do
        total_upload_size = Enum.sum(for e <- socket.assigns.uploads.photos.entries, do: e.client_size)

        socket
        |> assign(:upload_start_time, System.system_time(:millisecond))
        |> assign(:total_upload_size, total_upload_size)
      else
        socket
      end

    progress = Uploader.calculate_global_progress(socket.assigns.uploads.photos.entries)

    time_remaining =
      Uploader.calculate_time_remaining(socket.assigns.upload_start_time, socket.assigns.total_upload_size, progress)

    socket =
      if progress == 100 do
        push_event(socket, "js-exec", %{to: "#global-progress", attr: "data-on-finished"})
      else
        push_event(socket, "js-exec", %{to: "#global-progress", attr: "data-on-progress"})
      end

    {:noreply, socket |> assign(:global_progress, progress) |> assign(:time_remaining, time_remaining)}
  end
end
