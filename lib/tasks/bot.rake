namespace :bot do
  desc 'Run the Discord bot'
  # Invite link: https://discord.com/api/oauth2/authorize?client_id=823159664257662999&permissions=3263488&redirect_uri=https%3A%2F%2Fwww.google.com&response_type=code&scope=identify%20bot

  task run: :environment do
    require 'discordrb'
    include Bot::BotHelper

    discord_bot_token = Rails.application.credentials[Rails.env.to_sym][:discord_bot_token]
    return 'Aborting - could not find the Discord bot token in the credentials file!' if discord_bot_token.blank?

    bot = Discordrb::Bot.new(token: discord_bot_token, intents: %i[servers server_messages server_voice_states])

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
      message = help_message
      bot.send_message(event.channel, message)
    end

    bot.message(content: '.connect') do |event|
      channel = event.user.voice_channel
      bot.send_message(event.channel, "Connecting...")

      unless channel
        bot.send_message(event.channel, "You're not in any voice channel!")
        next
      end

      bot.voice_connect(channel)
      bot.send_message(event.channel, "Connected to voice channel: #{channel.name}")
    end

    bot.message(start_with: '.mpthree') do |event|
      filename = event.message.content.split(' ')&.second
      next unless filename

      sound = Sound.find_by_name(filename.downcase)

      unless sound.present?
        bot.send_message(event.channel, "#{random_insult_for(event.user.username)} This sound doesn't exist.")
        next
      end

      voice_bot = event.voice.presence || join_voice(bot, event)
      next unless voice_bot

      play_sound(voice_bot, sound)
    end

    bot.message(start_with: '.mpthreedirect') do |event|
      filename = Rails.root.join('lib', 'assets', 'sounds', "#{event.message.content.split(' ')&.second}.mp3")

      unless File.exist?(filename)
        bot.send_message(event.channel, "#{random_insult_for(event.user.username)} This sound doesn't exist.")
        next
      end

      voice_bot = event.voice.presence || join_voice(bot, event)
      next unless voice_bot

      # Since the DCA format is non-standard (i.e. ffmpeg doesn't support it), a separate method other than `play_file` has
      # to be used to play DCA files back. `play_dca` fulfills that role.
      voice_bot.play_io(filename.to_s)
    end

    bot.message(start_with: '.mpthreetempfile') do |event|
      filename = Rails.root.join('lib', 'assets', 'sounds', "#{event.message.content.split(' ')&.second}.mp3")

      unless File.exist?(filename)
        bot.send_message(event.channel, "#{random_insult_for(event.user.username)} This sound doesn't exist.")
        next
      end

      voice_bot = event.voice.presence || join_voice(bot, event)
      next unless voice_bot

      # Since the DCA format is non-standard (i.e. ffmpeg doesn't support it), a separate method other than `play_file` has
      # to be used to play DCA files back. `play_dca` fulfills that role.
      voice_bot.play_sound_from_local_storage(voice_bot, filename)
    end


    # DCA is a custom audio format developed by a couple people from the Discord API community (including myself, meew0).
    # It represents the audio data exactly as Discord wants it in a format that is very simple to parse, so libraries can
    # very easily add support for it. It has the advantage that absolutely no transcoding has to be done, so it is very
    # light on CPU in comparison to `play_file`.
    #
    # A conversion utility that converts existing audio files to DCA can be found here: https://github.com/RaymondSchnyder/dca-rs
    bot.message(start_with: '.s ') do |event|
      filename = event.message.content.split(' ')&.second
      next unless filename

      sound = Sound.find_by_name(filename.downcase)

      unless sound.present?
        bot.send_message(event.channel, "#{random_insult_for(event.user.username)} This sound doesn't exist.")
        next
      end

      voice_bot = event.voice.presence || join_voice(bot, event)
      next unless voice_bot

      play_sound(voice_bot, sound)
    end

    bot.message(start_with: '.say') do |event|
      text = event.message.content.sub('.say', '').strip
      next if text.empty?

      voice_bot = event.voice.presence || join_voice(bot, event)
      next unless voice_bot

      generate_and_play_tts(voice_bot, text)
    end

    bot.message(start_with: '.details') do |event|
      filename = event.message.content.split(' ').second
      next unless filename

      sound = Sound.find_by_name(filename.downcase)

      unless sound.present?
        bot.send_message(event.channel, "#{random_insult_for(event.user.username)} This sound doesn't exist.")
        next
      end

      max_volume, mean_volume = sound.max_and_mean_volume

      bot.send_message(event.channel, "Sound name: #{sound.name}\nID: #{sound.id}\nCreated at: #{sound.created_at}\nUpdated at: #{sound.updated_at}\nVolume adjustment: #{sound.volume_adjustment.presence || 'none'}\nMax volume: #{max_volume}dB\nMean volume: #{mean_volume}dB")
      next
    end

    bot.message(start_with: '.adjustvol') do |event|
      _, filename, db_adjustment = event.message.content.split(' ')
      next unless filename

      sound = Sound.find_by_name(filename.downcase)

      unless sound.present?
        bot.send_message(event.channel, "#{random_insult_for(event.user.username)} This sound doesn't exist.")
        next
      end

      if (db_adjustment = db_adjustment.to_f.round(2)).zero?
        bot.send_message(event.channel, "#{random_insult_for(event.user.username)} Send me the decibels too!.")
        next
      end

      if sound.adjust_volume!(db_adjustment)
        bot.send_message(event.channel, "Sound #{sound.name} volume adjusted by #{db_adjustment}dB (from baseline)!")
        next
      else
        bot.send_message(event.channel, "#{random_insult_for(event.user.username)} Sound #{sound.name} volume adjustment failed.")
        next
      end
    end

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

      bot.send_message(event.channel, 'Wait, doing my thing...')

      files = []

      begin
        event.message.attachments.each do |attachment|
          files << download_from_url(attachment.url)
        end
      rescue StandardError => e
        bot.send_message(event.channel, "Error parsing attachments: #{e.message}")
      end

      url = event.message.content.split(' ')&.second

      if url.present?
        begin
          files << download_from_url(url)
        rescue StandardError => e
          bot.send_message(event.channel, "Error opening the URL: #{e.message}")
        end
      end

      if files.blank?
        bot.send_message(event.channel, "You need to include a single .zip / .mp3 file as an URL or multiple .zip / .mp3 files as attachments.")
        next
      end

      successful_uploads, failed_uploads = create_sounds_from_zip_or_mp3_files(files)

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

    bot.message(start_with: '.rnsound') do |event|
      unless admin_permissions?(event.user.id)
        bot.send_message(event.channel, "You don't have the permission to rename sounds.")
        next
      end

      msg_parts = event.message.content.split(' ')

      next unless msg_parts && msg_parts.size == 3

      sound_name = msg_parts.second
      next unless sound_name

      new_sound_name = msg_parts.third
      next unless new_sound_name

      if Sound.find_by_name(sound_name.downcase)&.update(name: new_sound_name)
        bot.send_message(event.channel, "Sound #{sound_name} updated!")
      else
        bot.send_message(event.channel, "Couldn't update #{sound_name}.")
      end
    end

    bot.message(start_with: '.plainruby') do |event|
      unless super_admin_permissions?(event.user.id)
        bot.send_message(event.channel, "This is a danger zone and only my creator can do that. Sorry :(")
        next
      end

      ruby_code_string = event.message.content.split(' ')&.second
      next unless ruby_code_string.present?

      response = begin
                   eval(ruby_code_string)
                 rescue StandardError => error
                   error.inspect
                 end

      bot.send_message(event.channel, response.to_s)
    end

    bot.voice_state_update do |event|
      GC.start # Just help free up some memory

      next unless user_joined_voice_channel?(bot, event)

      sound_name = UserPreference.find_by_user_id(event.user.id)&.sound_name
      next unless sound_name

      voice_bot = bot.voice(event.channel.server.id).presence || join_voice_state_update_channel(bot, event)
      next unless voice_bot

      sound = Sound.find_by_name(sound_name)
      next unless sound.present?

      play_sound(voice_bot, sound, sleep_n_seconds: 1)
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
end
