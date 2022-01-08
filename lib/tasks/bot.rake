namespace :bot do
  desc 'Run the Discord bot'
  task run: :environment do
    require 'discordrb'
    require 'open-uri'
    require 'zip'

    discord_bot_token = Rails.application.credentials[Rails.env.to_sym][:discord_bot_token]
    return 'Aborting - could not find the Discord bot token in the credentials file!' if discord_bot_token.blank?

    bot = Discordrb::Bot.new token: discord_bot_token

    bot.message(start_with: '.addentrance') do |event|
      sound_name = event.message.content.split(' ')&.second&.downcase
      next unless sound_name

      unless Sound.where(name: sound_name).exists?
        bot.send_message(event.channel, 'This sound does not exist.')
        next
      end

      user_preference = UserPreference.find_or_initialize_by(user_id: event.user.id)
      user_preference.sound_name = sound_name
      user_preference.save

      bot.send_message(event.channel, "Sound #{sound_name} added as your entrance sound!")
    end

    bot.message(start_with: '.addinsult') do |event|
      insult_text = event.message.content.sub('.addinsult', '').strip
      next if insult_text.blank?

      Insult.find_or_create_by(content: insult_text)
      bot.send_message(event.channel, "Insult added! #{insult_text.gsub('[[name]]', event.user.username)}")
    end

    bot.message(content: '.rmentrance') do |event|
      defined_sounds = UserPreference.where(user_id: event.user.id)
      if defined_sounds.any?
        defined_sounds.destroy_all
        bot.send_message(event.channel, 'Entrance sound removed!')
      else
        bot.send_message(event.channel, "You didn't have any entrance sounds defined.")
      end
    end

    bot.message(content: '.list') do |event|
      list = Sound.all.pluck(:name).sort

      file_list = "```Available sounds :\n------------------\n\n"

      nb = 0
      list.each do |file|
        nb += 1

        while file.length < 15 do
          file += ' '
        end

        file_list += "#{file}\t"
        file_list += "\n" if (nb % 6).zero?

        if (nb % 42).zero?
          file_list += '```'
          bot.send_message(event.channel, file_list)
          file_list
          file_list = '```'
        end
      end
      file_list += '```'
      bot.send_message(event.channel, file_list) unless file_list == '``````'
    end

    bot.message(content: '.help') do |event|
      message = "Bot usage:
`.list` - displays the list of all available sounds
`.s [sound]` - plays the sound
`.addentrance [sound]` - adds the sound to your entrance
`.rmentrance` - removes any entrance sound you might have
`.addinsult [insult text]` - adds an insult to be used when an user does something wrong with the bot (e.g. non-existent sound). Pro tip: if you want to dynamically address the user in the insult, use [[name]] in the insult."
      bot.send_message(event.channel, message)
    end

    bot.message(content: '.connect') do |event|
      # The `voice_channel` method returns the voice channel the user is currently in, or `nil` if the user is not in a
      # voice channel.
      channel = event.user.voice_channel

      # Here we return from the command unless the channel is not nil (i.e. the user is in a voice channel). The `next`
      # construct can be used to exit a command prematurely, and even send a message while we're at it.
      unless channel
        bot.send_message(event.channel, "You're not in any voice channel!")
        next
      end

      # The `voice_connect` method does everything necessary for the bot to connect to a voice channel. Afterwards the bot
      # will be connected and ready to play stuff back.
      bot.voice_connect(channel)
      bot.send_message(event.channel, "Connected to voice channel: #{channel.name}")
    end

    # A simple command that plays back an mp3 file.
    bot.message(start_with: '.s') do |event|
      # `event.voice` is a helper method that gets the correct voice bot on the server the bot is currently in. Since a
      # bot may be connected to more than one voice channel (never more than one on the same server, though), this is
      # necessary to allow the differentiation of servers.
      #
      # It returns a `VoiceBot` object that methods such as `play_file` can be called on.
      filename = event.message.content.split(' ')&.second
      next unless filename

      sound = Sound.find_by_name(filename.downcase)

      unless sound.present?
        bot.send_message(event.channel, "#{random_insult_for(event.user.username)} This sound doesn't exist.")
        next
      end

      voice_bot = event.voice.presence || join_voice(bot, event)
      next unless voice_bot

      sound_file = Tempfile.new
      sound_file.binmode
      sound_file.write(sound.file)

      voice_bot.play_file(sound_file.path)
    end

    # DCA is a custom audio format developed by a couple people from the Discord API community (including myself, meew0).
    # It represents the audio data exactly as Discord wants it in a format that is very simple to parse, so libraries can
    # very easily add support for it. It has the advantage that absolutely no transcoding has to be done, so it is very
    # light on CPU in comparison to `play_file`.
    #
    # A conversion utility that converts existing audio files to DCA can be found here: https://github.com/RaymondSchnyder/dca-rs
    bot.message(start_with: '.dca') do |event|
      filename = Rails.root.join('lib', 'assets', 'sounds', 'dca', "#{event.message.content.split(' ')&.second}.dca")

      unless File.exist?(filename)
        bot.send_message(event.channel, "#{random_insult_for(event.user.username)} This sound doesn't exist.")
        next
      end

      voice_bot = event.voice.presence || join_voice(bot, event)
      next unless voice_bot

      # Since the DCA format is non-standard (i.e. ffmpeg doesn't support it), a separate method other than `play_file` has
      # to be used to play DCA files back. `play_dca` fulfills that role.
      voice_bot.play_dca(filename)
    end

    bot.message(start_with: '.uploadsounds') do |event|
      unless admin_permissions?(event.user.id)
        bot.send_message(event.channel, "You don't have the permission to upload sounds.")
        next
      end

      url = event.message.content.split(' ')&.second
      next unless url

      bot.send_message(event.channel, 'Wait, doing my thing...')

      begin
        zipfile = URI.parse(url).open
      rescue StandardError => e
        bot.send_message(event.channel, "Error opening the URL: #{e.message}")
        next
      end

      failed_uploads = []
      successful_uploads = []

      Zip::File.open_buffer(zipfile) do |zip_file_content|
        zip_file_content.each do |f|
          unless f.name.end_with?('.mp3')
            failed_uploads << "#{f.name} - wrong file type"
            next
          end

          if create_sound_object_with_file(f)
            successful_uploads << f.name
          else
            failed_uploads << f.name
          end
        end
      end

      if successful_uploads.any?
        file_list = "```Successfully uploaded these sounds:\n------------------\n\n"
        file_list += successful_uploads.join("\n")
        file_list += '```'
        bot.send_message(event.channel, file_list)
      end

      if failed_uploads.any?
        file_list = "```Failed to upload these sounds:\n------------------\n\n"
        file_list += failed_uploads.join("\n")
        file_list += '```'
        bot.send_message(event.channel, file_list)
      end

      if successful_uploads.blank? && failed_uploads.blank?
        bot.send_message(event.channel, "Not sure what you did, but it didn't work.")
      end
    end

    bot.message(start_with: '.rmsound') do |event|
      unless admin_permissions?(event.user.id)
        bot.send_message(event.channel, "You don't have the permission to remove sounds.")
        next
      end

      sound_name = event.message.content.split(' ')&.second
      next unless sound_name

      if Sound.find_by_name(sound_name.downcase)&.destroy
        bot.send_message(event.channel, "Sound #{sound_name} removed!")
      else
        bot.send_message(event.channel, "Couldn't remove #{sound_name}.")
      end
    end

    bot.voice_state_update do |event|
      next unless event.channel
      next if event.user.id == bot.profile.id
      next if event.old_channel.present? && event.channel.present?
      next unless event.old_channel.blank? && event.channel.present?

      sound_name = UserPreference.find_by_user_id(event.user.id)&.sound_name
      next unless sound_name

      voice_bot = bot.voice(event.channel.server.id).presence || join_voice_state_update_channel(bot, event)
      next unless voice_bot

      file_binary = Sound.find_by_name(sound_name)&.file
      next unless file_binary

      sound_file = Tempfile.new
      sound_file.binmode
      sound_file.write(file_binary)

      sleep 1
      voice_bot.play_file(sound_file.path)
    end

    bot.run
  end

  def join_voice(bot, event)
    channel = event.user.voice_channel
    unless channel
      event.respond "#{random_insult_for(event.user.username)} You're not in any voice channel!"
      return
    end

    bot.voice_connect(channel)
    event.voice
  end

  def join_voice_state_update_channel(bot, event)
    channel = event.channel
    unless channel
      event.respond "You're not in any voice channel!"
      return
    end

    bot.voice_connect(channel)
    bot.voice(event.channel.server.id)
  end

  def random_insult_for(username)
    Insult.order('RANDOM()').first.content.gsub('[[name]]', username)
  end

  def create_sound_object_with_file(file)
    return false unless file.name.end_with?('.mp3')

    path = ''
    Tempfile.open(file.name) do |tmp|
      file.extract(tmp.path) { true }
      path = tmp.path
    end
    sound = Sound.create(name: file.name.sub('.mp3', ''), file: File.binread(path))
    sound.save
  end

  def admin_permissions?(user_id)
    {
      '295222341862948872' => 'yago',
      '683678616994840628' => 'rasmus',
      '318091282214027274' => 'walnut',
      '810534867846299668' => 'wang'
    }[user_id.to_s].present?
  end
end
