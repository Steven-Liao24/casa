require "active_support/core_ext/integer/time"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.
  config.action_mailer.default_url_options = {host: "localhost", port: 3000} # for devise authentication
  # While tests run files are not watched, reloading is not necessary.
  # Turn false under Spring and add config.action_view.cache_template_loading = true.
  config.action_view.cache_template_loading = true

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?
  # cache classes on CI, but enable reloading for local work (bin/rspec)
  config.enable_reloading = ENV["CI"].blank?
  # Configure public file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.headers = {
    "Cache-Control" => "public, max-age=#{1.hour.to_i}"
  }

  # Show full error reports and disable caching.
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  # config.cache_store = :null_store

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = :none

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Rack Attack configuration
  # Set IP_BLOCKLIST for testing. Can't stub in spec since environment variable
  # gets read during application initialization.
  ENV["IP_BLOCKLIST"] = "4.5.6.7, 9.8.7.6,100.101.102.103"

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raises error for missing translations.
  config.i18n.raise_on_missing_translations = true

  config.after_initialize do
    Bullet.enable = true
    Bullet.console = true
    Bullet.bullet_logger = true
    Bullet.rails_logger = true
    # Bullet.raise = true # TODO https://github.com/rubyforgood/casa/issues/2441
  end

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions
  config.action_controller.raise_on_missing_callback_actions = false

  # https://github.com/rails/rails/issues/48468
  config.active_job.queue_adapter = :test
end
