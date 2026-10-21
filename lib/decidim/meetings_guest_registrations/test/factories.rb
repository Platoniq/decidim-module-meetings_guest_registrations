# frozen_string_literal: true

require "decidim/components/namer"
require "decidim/core/test/factories"

FactoryBot.define do
  factory :meetings_guest_registrations_component, parent: :component do
    name { Decidim::Components::Namer.new(participatory_space.organization.available_locales, :meetings_guest_registrations).i18n_name }
    manifest_name :meetings_guest_registrations
    participatory_space { create(:participatory_process, :with_steps) }
  end

  # Add engine factories here
end
