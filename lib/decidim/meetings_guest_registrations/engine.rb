# frozen_string_literal: true

require "rails"
require "decidim/core"

module Decidim
  module MeetingsGuestRegistrations
    # This is the engine that runs on the public interface of meetings_guest_registrations.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::MeetingsGuestRegistrations

      routes do
        # Add engine routes here
        # resources :meetings_guest_registrations
        # root to: "meetings_guest_registrations#index"
      end

      initializer "MeetingsGuestRegistrations.shakapacker.assets_path" do
        Decidim.register_assets_path File.expand_path("app/packs", root)
      end

      initializer "MeetingsGuestRegistrations.data_migrate", after: "decidim_core.data_migrate" do
        DataMigrate.configure do |config|
          config.data_migrations_path << root.join("db/data").to_s
        end
      end
    end
  end
end
