class Sound < ApplicationRecord
  validates :name, :file, presence: true
  validates_uniqueness_of :name

  def max_and_mean_volume
    sound_file = Tempfile.new
    sound_file.binmode
    sound_file.write(file)
    sound_file.rewind

    cmd = "ffmpeg -hide_banner -i #{sound_file.path} -af volumedetect -vn -f null -"
    ffmpeg_output = IO.popen(cmd, err: [:child, :out], &:read)

    max_volume = ffmpeg_output[/max_volume: ([\-\d\.]+) dB/, 1]&.to_f
    mean_volume = ffmpeg_output[/mean_volume: ([\-\d\.]+) dB/, 1]&.to_f

    [max_volume, mean_volume]
  ensure
    sound_file.close
    sound_file.unlink
  end

  def adjust_volume!(db)
    self.update(volume_adjustment: db)
  end

  def binary_with_adjusted_volume
    # IMPORTANT: Wherever you use this method. make sure to close and unlink the return value of this function.

    input_sound_file = Tempfile.new(%w[input_sound .mp3])
    input_sound_file.binmode
    input_sound_file.write(file)
    input_sound_file.rewind

    return input_sound_file if volume_adjustment.nil? || volume_adjustment.zero?

    output_sound_file = Tempfile.new(%w[output_sound .mp3])
    output_sound_file.binmode

    cmd = "ffmpeg -i #{input_sound_file.path} -filter:a \"volume=#{volume_adjustment}dB\" -y #{output_sound_file.path}"
    ffmpeg_output = IO.popen(cmd, err: [:child, :out], &:read)

    input_sound_file.close
    input_sound_file.unlink

    output_sound_file.rewind

    ffmpeg_success = ffmpeg_output.include?('Duration:') && File.exist?(output_sound_file.path) && !File.zero?(output_sound_file.path)
    ffmpeg_success ? output_sound_file : input_sound_file
  end
end
