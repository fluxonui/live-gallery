defmodule LiveGalleryWeb.SharedComponents do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  attr :progress, :integer, default: 0
  attr :class, :string, default: nil

  def circular_progress(assigns) do
    assigns = assign(assigns, :circumference, 2 * :math.pi() * 120)
    assigns = assign(assigns, :offset, assigns.circumference - assigns.progress / 100 * assigns.circumference)

    ~H"""
    <div class={["flex items-center justify-center", @class]}>
      <svg viewBox="0 0 290 290" class="w-full h-full transform -rotate-90">
        <circle cx="145" cy="145" r="120" stroke-width="20" fill="transparent" class="stroke-white opacity-30" />

        <circle
          cx="145"
          cy="145"
          r="120"
          stroke-width="20"
          fill="transparent"
          stroke-dasharray={@circumference}
          stroke-dashoffset={@offset}
          class="stroke-white"
          stroke-linecap="round"
        />
      </svg>
      <span class="absolute text-white text-sm font-semibold">{@progress}%</span>
    </div>
    """
  end

  attr :progress, :integer, required: true
  attr :total_entries, :integer, required: true
  attr :completed_entries, :integer, required: true
  attr :time_remaining, :integer
  attr :class, :string, default: nil

  def upload_progress(assigns) do
    ~H"""
    <div
      class={[
        "max-w-md w-full border rounded-xl px-4 py-3 bg-zinc-900 text-white absolute top-4 left-1/2 -translate-x-1/2 items-center gap-4 hidden",
        @class
      ]}
      id="global-progress"
      data-on-progress={show_upload_progress()}
      data-on-finished={hide_upload_progress()}
    >
      <div class="grid grid-cols-3">
        <span class="text-left text-sm font-bold text-white">Upload progress</span>
        <span class="text-center text-sm font-semibold text-gray-100">
          {@progress}% ({@completed_entries}/{@total_entries})
        </span>

        <span :if={@time_remaining} class="text-right font-semibold text-sm text-gray-100">
          {format_time_remaining(@time_remaining)} remaining
        </span>
      </div>

      <div class="mt-2 h-2 bg-zinc-700 rounded-full overflow-hidden">
        <div class="h-full bg-white transition-all duration-300 ease-out" style={"width: #{@progress}%"}></div>
      </div>
    </div>
    """
  end

  def show_upload_progress(js \\ %JS{}) do
    js
    |> JS.show(
      to: "#global-progress",
      transition: {"ease-out duration-300", "opacity-0 -translate-y-full", "opacity-100 translate-y-0"}
    )
  end

  def hide_upload_progress(js \\ %JS{}) do
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
end
