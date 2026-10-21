# frozen_string_literal: true

base_path = File.expand_path("..", __dir__)

Decidim::Shakapacker.register_path("#{base_path}/app/packs")
Decidim::Shakapacker.register_entrypoints(
  decidim_meetings_guest_registrations: "#{base_path}/app/packs/entrypoints/decidim_meetings_guest_registrations.js"
)
Decidim::Shakapacker.register_stylesheet_import("stylesheets/decidim/meetings_guest_registrations/meetings_guest_registrations")
