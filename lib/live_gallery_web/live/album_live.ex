defmodule LiveGalleryWeb.AlbumLive do
  use LiveGalleryWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:album, %{name: "Best of 2024", access: "private"})
     |> assign(:album_form, to_form(%{"name" => "Best of 2024", "access" => "private"}))
     |> assign(:uploaded_files, [])
     |> assign(:uploading, false)
     |> assign(:global_progress, 0)
     |> assign(:show_progress, false)
     |> assign(:time_remaining, nil)
     |> assign(:upload_start_time, nil)
     |> assign(:total_size, 0)
     |> allow_upload(:photos,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 99,
       auto_upload: true,
       external: &presign_upload/2,
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

        <div
          class="max-w-md hidden w-full border rounded-xl px-4 py-3 bg-zinc-900 text-white absolute top-4 left-1/2 -translate-x-1/2 items-center gap-4"
          id="global-progress"
          data-on-progress={show_progress()}
          data-on-finished={hide_progress()}
        >
          <div class="grid grid-cols-3">
            <span class="text-left text-sm font-bold text-white">Upload progress</span>
            <span class="text-center text-sm font-semibold text-gray-100">
              {@global_progress}% ({length(Enum.filter(@uploads.photos.entries, & &1.done?))}/{length(
                @uploads.photos.entries
              )})
            </span>

            <span :if={@time_remaining} class="text-right font-semibold text-sm text-gray-100">
              {format_time_remaining(@time_remaining)} remaining
            </span>
          </div>

          <div class="mt-2 h-2 bg-zinc-700 rounded-full overflow-hidden">
            <div class="h-full bg-white transition-all duration-300 ease-out" style={"width: #{@global_progress}%"}></div>
          </div>
        </div>

        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4 mt-10">
          <form class="relative aspect-square" phx-change="validate" phx-submit="upload-photos">
            <.live_file_input upload={@uploads.photos} class="absolute inset-0 w-full h-full opacity-0 cursor-pointer peer" />
            <div class="aspect-square flex items-center flex-col px-6 text-center justify-center border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-zinc-800 transition-colors peer-hover:border-gray-400 dark:peer-hover:border-gray-500">
              <.icon name="hero-camera" class="size-9 text-gray-300 dark:text-gray-500 pointer-events-none" />
              <span class="font-medium mt-2 dark:text-white">Select images</span>
              <p class="text-sm text-gray-500 dark:text-gray-400">or drag photos from your computer</p>
            </div>
          </form>

          <article :for={entry <- @uploads.photos.entries} class="overflow-hidden rounded-lg relative">
            <figure class="aspect-square">
              <.live_img_preview entry={entry} class="w-full h-full object-cover" />
            </figure>

            <div :if={not entry.done?} class="flex items-center justify-center absolute inset-0 m-auto">
              <.progress_bar progress={entry.progress} class="w-16 h-16" />
            </div>

            <p :for={err <- upload_errors(@uploads.photos, entry)} class="alert alert-danger">{error_to_string(err)}</p>
          </article>
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

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save-album-name", %{"name" => name}, socket) do
    {:noreply, socket |> assign(:album, %{socket.assigns.album | name: name})}
  end

  def handle_event("update-album-access", %{"access" => access}, socket) do
    {:noreply, socket |> assign(:album, %{socket.assigns.album | access: access})}
  end

  def presign_upload(entry, socket) do
    config = ExAws.Config.new(:s3)
    bucket = "live-gallery"
    key = "public/#{entry.client_name}"

    {:ok, url} =
      ExAws.S3.presigned_url(config, :put, bucket, key,
        expires_in: 3600,
        query_params: [{"Content-Type", entry.client_type}],
        headers: [
          {"Content-Type", entry.client_type},
          {"x-amz-acl", "private"}
        ]
      )

    {:ok, %{uploader: "S3", key: key, url: url}, socket}
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp error_to_string(:too_many_files), do: "You have selected too many files"

  def show_progress(js \\ %JS{}) do
    js
    |> JS.show(
      to: "#global-progress",
      transition: {"ease-out duration-300", "opacity-0 -translate-y-full", "opacity-100 translate-y-0"}
    )
  end

  def hide_progress(js \\ %JS{}) do
    js
    |> JS.hide(
      to: "#global-progress",
      transition: {"ease-in duration-200", "opacity-100 translate-y-0", "opacity-0 -translate-y-full"}
    )
  end

  defp format_time_remaining(seconds) when seconds < 60, do: "#{seconds}s"

  defp format_time_remaining(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}m #{remaining_seconds}s"
  end

  defp format_time_remaining(_seconds), do: "1h+"

  def handle_progress(:photos, _entry, socket) do
    socket =
      if is_nil(socket.assigns.upload_start_time) do
        total_size = Enum.sum(for e <- socket.assigns.uploads.photos.entries, do: e.client_size)

        socket
        |> assign(:upload_start_time, System.system_time(:millisecond))
        |> assign(:total_size, total_size)
      else
        socket
      end

    progress = calculate_global_progress(socket.assigns.uploads.photos.entries)
    time_remaining = calculate_time_remaining(socket, progress)

    socket =
      if progress == 100 do
        socket
        |> push_event("js-exec", %{to: "#global-progress", attr: "data-on-finished"})
      else
        if socket.assigns.show_progress do
          socket
        else
          socket
          |> push_event("js-exec", %{to: "#global-progress", attr: "data-on-progress"})
        end
      end

    {:noreply, socket |> assign(:global_progress, progress) |> assign(:time_remaining, time_remaining)}
  end

  defp calculate_global_progress([]), do: 0

  defp calculate_global_progress(entries) do
    total_progress = Enum.sum(Enum.map(entries, & &1.progress))
    (total_progress / length(entries)) |> round()
  end

  defp calculate_time_remaining(socket, progress) do
    case {socket.assigns.upload_start_time, progress} do
      {nil, _} ->
        nil

      {_, 0} ->
        nil

      {start_time, progress} ->
        current_time = System.system_time(:millisecond)
        elapsed_time = max((current_time - start_time) / 1000, 0.001)

        uploaded_size = socket.assigns.total_size * (progress / 100)
        upload_speed = uploaded_size / elapsed_time

        remaining_size = socket.assigns.total_size - uploaded_size

        case upload_speed do
          speed when speed <= 0 -> nil
          speed -> round(remaining_size / speed)
        end
    end
  end
end
