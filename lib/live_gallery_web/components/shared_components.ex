defmodule LiveGalleryWeb.SharedComponents do
  use Phoenix.Component

  # alias Phoenix.LiveView.JS

  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  attr :progress, :integer, default: 0
  attr :class, :string, default: nil

  def progress_bar(assigns) do
    assigns = assign(assigns, :circumference, 2 * 22 / 7 * 120)
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
end
