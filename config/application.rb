require_relative "boot"

require "rails"
# This list is here as documentation only - it's not used
omitted = %w(
  active_storage/engine
  action_cable/engine
  action_mailbox/engine
  action_text/engine
  sprockets/railtie
  action_view/railtie
  action_mailer/railtie
  active_job/railtie
  action_controller/railtie
  rails/test_unit/railtie
)

# Only the frameworks in Rails that do not pollute our routes
%w(
  active_record/railtie
).each do |railtie|
  begin
    require railtie
  rescue LoadError
  end
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Ebeningbot
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    config.middleware.insert_before 0, Rack::Cors do
      allow do
        origins 'http://localhost:3000', '0.0.0.0:3000', 'https://treevia.netlify.app'
        resource '/api/*', headers: :any, methods: %i[get post options]
      end
    end


    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
