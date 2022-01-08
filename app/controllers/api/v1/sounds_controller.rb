class Api::V1::SoundsController < ApplicationController
  def index
    @sounds = Sound.all
    render json: @sounds, except: [:file]
  end

  def create
    fail('No file included', status: :bad_request) && return if sound_params.blank? || sound_params[:file].blank?
    fail('Invalid file type', status: :unsupported_media_type) && return unless sound_params[:file]&.content_type == 'audio/mpeg'

    name = sound_params[:file].original_filename.sub('.mp3', '')&.downcase
    fail('Invalid name') && return if name.blank? || name.include?(' ') || name.length > 15

    file = sound_params[:file].tempfile.read
    sound = Sound.new(name: name, file: file)
    fail(sound.errors.full_messages) && return unless sound.save

    render json: { success: true }, status: :created
  end

  private

  def sound_params
    params.permit(:file)
  end

  def fail(message, status: :unprocessable_entity)
    message = [message] unless message.is_a?(Array)
    render json: { success: false, messages: message }, status: status
  end
end
