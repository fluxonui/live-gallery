defmodule LiveGalleryWeb.Uploader do
  def calculate_global_progress([]), do: 0

  def calculate_global_progress(entries) do
    total_progress = Enum.sum(Enum.map(entries, & &1.progress))
    (total_progress / length(entries)) |> round()
  end

  def calculate_time_remaining(start_time, _total_size, _progress) when is_nil(start_time), do: nil
  def calculate_time_remaining(_start_time, _total_size, 0), do: nil

  # This uses the following formula to calculate the estimated time to finish:
  # time_remaining = (total_size - uploaded_size) / upload_speed
  def calculate_time_remaining(start_time, total_size, progress) do
    current_time = System.system_time(:millisecond)

    # Uses a millisecond to avoid division by 0
    elapsed_time = max((current_time - start_time) / 1000, 0.001)

    # Calculate how many bytes have been uploaded based on progress percentage
    uploaded_size = total_size * (progress / 100)

    # Calculate upload speed in bytes per second
    upload_speed = uploaded_size / elapsed_time

    # Calculate remaining bytes to upload
    remaining_size = total_size - uploaded_size

    # Return nil if speed is 0 or negative, otherwise calculate seconds remaining
    case upload_speed do
      speed when speed <= 0 -> nil
      speed -> round(remaining_size / speed)
    end
  end

  def presign_upload(entry) do
    config = ExAws.Config.new(:s3)
    bucket = "live-gallerys"
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

    {:ok, %{uploader: "S3", key: key, url: url}}
  end

  def error_to_string(:too_large), do: "Too large"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  def error_to_string(:too_many_files), do: "You have selected too many files"
  def error_to_string(:external_client_failure), do: "Failed to upload file"
end
