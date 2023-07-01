module Bot::BotHelper
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
      sound_file = Tempfile.new("#{sound.name}.mp3", encoding: 'ascii-8bit')
      sound_file.binmode
      sound_file.write(sound.file)

      sleep sleep_n_seconds if sleep_n_seconds.positive?

      voice_bot.play_file(sound_file.path)
    ensure
      sound_file.close
      sound_file.unlink
    end
  end

  def download_zip_from_url(url)
    URI.parse(url).open
  end

  def create_sounds_from_zip_file(zip_file)
    failed_uploads = []
    successful_uploads = []

    Zip::File.open_buffer(zip_file) do |zip_file_content|
      zip_file_content.each do |f|
        unless f.name.end_with?('.mp3')
          failed_uploads << "#{f.name} - wrong file type"
          next
        end

        if create_sound_object_with_file(zip_file_content, f)
          successful_uploads << f.name
        else
          failed_uploads << f.name
        end
      end
    end

    [successful_uploads, failed_uploads]
  end

  def create_sound_object_with_file(zip_file_content, file)
    return false unless file.name.end_with?('.mp3')

    tempfile = Tempfile.new(file.name)
    tempfile.binmode
    tempfile.write zip_file_content.read(file)
    tempfile.rewind
    sound = Sound.create(name: file.name.sub('.mp3', ''), file: tempfile.read)
    success = sound.save
    tempfile.close
    tempfile.unlink
    success
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
      '636656143048900621' => 'dot'
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
