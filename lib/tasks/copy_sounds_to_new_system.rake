SOUND_FILES_PATH = Rails.root.join('lib', 'assets', 'sounds')

namespace :copy_sounds do
  desc 'Copy sounds from lib/assets/sounds to the new ActiveRecord system'
  task run: :environment do
    failed_uploads = []
    successful_uploads = []

    Dir.entries(SOUND_FILES_PATH).each do |file_name|
      unless file_name.end_with?('.mp3')
        failed_uploads << "#{file_name} - wrong file type"
        next
      end

      if copy_file_to_sound_object(file_name)
        successful_uploads << file_name
      else
        failed_uploads << file_name
      end
    end

    if successful_uploads.any?
      p 'Successfully uploaded these sounds:'
      p successful_uploads.join("\n")
    end

    if failed_uploads.any?
      p 'Failed to upload these sounds:'
      p failed_uploads.join("\n")
    end

    p "Not sure what you did, but it didn't work." if successful_uploads.blank? && failed_uploads.blank?
  end

  def copy_file_to_sound_object(file_name)
    return false unless file_name.end_with?('.mp3')

    sound = Sound.create(name: file_name.sub('.mp3', ''), file: File.binread(SOUND_FILES_PATH.join(file_name)))
    sound.save
  end
end
