module Bot::BotHelper
  FILE_NAME_REGEX = /\A[a-z0-9]*\.mp3\z/

  require 'open-uri'
  require 'zip'

  def help_message
    "Bot usage:
`.list` - displays the list of all available sounds
`.s [sound]` - plays the sound
`.addentrance [sound]` - adds the sound to your entrance
`.rmentrance` - removes any entrance sound you might have
`.addinsult [insult text]` - adds an insult to be used when an user does something wrong with the bot (e.g. non-existent sound). Pro tip: if you want to dynamically address the user in the insult, use [[name]] in the insult."
  end

  def play_sound(voice_bot, sound, sleep_n_seconds: 0)
    begin
      sound_file = sound.binary_with_adjusted_volume
      sleep sleep_n_seconds if sleep_n_seconds.positive?

      voice_bot.play_file(sound_file.path)
    ensure
      sound_file.close
      sound_file.unlink
    end
  end

  def play_sound_from_local_storage(voice_bot, filename, sleep_n_seconds: 0)
    begin
      sound_file = Tempfile.new
      sound_file.binmode
      sound_file.write(File.read(filename))
      sound_file.rewind

      sleep sleep_n_seconds if sleep_n_seconds.positive?

      voice_bot.play_io(sound_file.path)
    ensure
      sound_file.close
      sound_file.unlink
    end
  end

  def download_from_url(url)
    f = URI.parse(url).open

    {
      filename: f.meta['content-disposition'].match(/filename=(\"?)(.+)\1/)[2],
      content: f.read
    }
  end

  def create_sounds_from_zip_or_mp3_files(files)
    successful_uploads = []
    failed_uploads = []

    files.each do |file|
      if file[:filename].end_with?('.mp3')
        process_mp3_file(file, successful_uploads, failed_uploads)
      elsif file[:filename].end_with?('.zip')
        process_zip_file(file, successful_uploads, failed_uploads)
      else
        failed_uploads << "#{file[:filename]} - wrong file type"
      end
    end

    [successful_uploads, failed_uploads]
  end

  def process_mp3_file(file, successful_uploads, failed_uploads)
    if valid_file_name?(file[:filename])
      if create_sound_object(file[:filename], file[:content])
        successful_uploads << file[:filename]
      else
        failed_uploads << file[:filename]
      end
    else
      failed_uploads << "#{file[:filename]} - invalid name"
    end
  end

  def process_zip_file(file, successful_uploads, failed_uploads)
    Zip::File.open_buffer(file[:content]) do |zip_file_content|
      zip_file_content.each do |entry|
        process_zip_entry(zip_file_content, entry, successful_uploads, failed_uploads)
      end
    end
  end

  def process_zip_entry(zip_file_content, entry, successful_uploads, failed_uploads)
    if !entry.name.end_with?('.mp3')
      failed_uploads << "#{entry.name} - wrong file type"
    elsif !valid_file_name?(entry.name)
      failed_uploads << "#{entry.name} - invalid name"
    else
      if create_sound_object(entry.name, zip_file_content.read(entry))
        successful_uploads << entry.name
      else
        failed_uploads << entry.name
      end
    end
  end

  def valid_file_name?(filename)
    filename.match?(FILE_NAME_REGEX)
  end

  def create_sound_object(filename, content)
    Tempfile.create(filename) do |tempfile|
      tempfile.binmode
      tempfile.write(content)
      tempfile.rewind
      Sound.create(name: filename.sub('.mp3', ''), file: tempfile.read).save
    end
  end


  def random_insult_for(username)
    Insult.order('RANDOM()').first&.content&.gsub('[[name]]', username) || ''
  end

  def admin_permissions?(user_id)
    {
      '295222341862948872' => 'yago',
      '683678616994840628' => 'rasmus',
      '318091282214027274' => 'walnut',
      '810534867846299668' => 'wang',
      '971816463553933373' => 'harry',
      '326131124646576138' => 'vici',
      '123475794503794690' => 'toxic',
      '937025440864944148' => 'pudsey'
    }[user_id.to_s].present?
  end

  def super_admin_permissions?(user_id)
    user_id.present? && user_id.to_s == '683678616994840628'.freeze
  end

  # def every_n_seconds(n)
  #   thread = Thread.new do
  #     loop do
  #       before = Time.now
  #       yield
  #       interval = n - (Time.now - before)
  #       sleep(interval) if interval.positive?
  #     end
  #   end
  #   thread
  # end
  #
  # def stop_bot_after_n_seconds_of_inactivity(voice_bot, n = 5)
  #   p "here..."
  #   every_n_seconds(5) do
  #     p "checking..."
  #
  #     if Time.now - @last_event >= n
  #       p "Bot has been idle for more than #{n} seconds, stopping..."
  #       voice_bot.destroy
  #     end
  #   end
  # end

  def user_joined_voice_channel?(bot, event)
    event.old_channel.blank? && event.channel.present? && event.user.id != bot.profile.id
  end
end
