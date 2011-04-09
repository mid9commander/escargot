require "escargot"
require "rails"
require "active_model/railtie"

module Escargot
  # = MongoMapper Railtie
  class Railtie < Rails::Railtie

    config.escargot = ActiveSupport::OrderedOptions.new

    rake_tasks do
      load "escargot/railtie/escargot.rake"
    end

    initializer "escargot.set_configs" do |app|
      ActiveSupport.on_load(:escargot) do
        app.config.escargot.each do |k,v|
          send "#{k}=", v
        end
      end
    end

    # This sets the database configuration and establishes the connection.
    initializer "escargot.initialize_database" do |app|
      config_file = Rails.root.join('config/elasticsearch.yml')
      if config_file.file?
        config = YAML.load_file(RAILS_ROOT + "/config/elasticsearch.yml")
        Escargot.setup(config, Rails.env, :logger => Rails.logger)
      else
        Escargot.default_setup(nil, Rails.env, :logger => Rails.logger)
      end
    end
  end
end
