defmodule LiveGalleryWeb.AlbumLive do
  use LiveGalleryWeb, :live_view

  # alias LiveGallery.S3Uploader

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> assign(:uploading, false)
     |> assign(:global_progress, 0)
     |> assign(:show_progress, false)
     |> allow_upload(:photos,
       accept: ~w(.jpg .jpeg .png),
       max_entries: 10,
       auto_upload: true,
       external: &presign_upload/2,
       progress: &handle_progress/3
     )}
  end

  def handle_progress(:photos, _entry, socket) do
    progress = calculate_global_progress(socket.assigns.uploads.photos.entries)

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

    {:noreply, assign(socket, :global_progress, progress)}
  end

  defp calculate_global_progress([]), do: 0

  defp calculate_global_progress(entries) do
    total_progress = Enum.sum(Enum.map(entries, & &1.progress))
    (total_progress / length(entries)) |> round()
  end

  def render(assigns) do
    ~H"""
    <div class="flex h-full">
      <div class="flex-1 p-10">
        <h1 class="text-2xl font-bold">Album Photos</h1>

        <div
          class="hidden border rounded-full px-4 py-2 bg-zinc-900 text-white absolute top-2 left-1/2 -translate-x-1/2"
          id="global-progress"
          data-on-progress={show_progress()}
          data-on-finished={hide_progress()}
        >
          <div class="w-32 h-2 bg-zinc-700 rounded-full overflow-hidden mr-2">
            <div class="h-full bg-white transition-all duration-300 ease-out" style={"width: #{@global_progress}%"}></div>
          </div>

          {@global_progress}%
        </div>

        <div class="grid grid-cols-4 gap-4 mt-10">
          <form class="relative aspect-square" phx-change="validate" phx-submit="upload-photos">
            <.live_file_input upload={@uploads.photos} class="absolute inset-0 w-full h-full opacity-0 cursor-pointer" />
            <div class="aspect-square flex items-center flex-col px-6 text-center justify-center border border-dashed border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
              <.icon name="hero-camera" class="size-9 text-gray-300 pointer-events-none" />
              <span class="font-medium mt-2">Select images</span>
              <p class="text-sm text-gray-500">or drag photos from your computer</p>
            </div>
          </form>
          <article :for={entry <- @uploads.photos.entries} class="overflow-hidden rounded-lg relative">
            {inspect(entry)}
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

      <div class="max-w-xs w-full border-l h-full p-10">
        <h2 class="text-xl font-bold">Settings</h2>
      </div>
    </div>
    """
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def presign_upload(entry, socket) do
    config = ExAws.Config.new(:s3)
    bucket = "live-gallery"
    key = "public/#{entry.client_name}"

    {:ok, url} =
      ExAws.S3.presigned_url(config, :put, bucket, key,
        expires_in: 3600,
        query_params: [
          {"Content-Type", entry.client_type}
        ],
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
      transition: {"ease-out duration-1000", "opacity-0 -translate-y-full", "opacity-100 translate-y-0"}
    )
  end

  def hide_progress(js \\ %JS{}) do
    js
    |> JS.hide(
      to: "#global-progress",
      transition: {"ease-in duration-200", "opacity-100 translate-y-0", "opacity-0 -translate-y-full"}
    )
  end
end
