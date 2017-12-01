require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
# require "sprockets/railtie"
require "rails/test_unit/railtie"
require "telegram/bot"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ShaurmaBot
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.1
    config.time_zone = 'Moscow'
    config.session_store :cookie_store
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, config.session_options
    config.middleware.use Rack::MethodOverride
    config.paperclip_defaults = {
        storage: :s3,
        url: ':s3_domain_url',
        s3_region: 'eu-central-1',
        s3_host_name: 's3.eu-central-1.amazonaws.com',
        s3_protocol: 'https',
        path: '/:class/:attachment/:id_partition/:style/:filename',
        s3_credentials: {
            bucket: 'statictgbot',
            access_key_id: 'AKIAIGPYEROJQ4RT75SA',
            secret_access_key: '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'
        }
    }
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
  end
end
