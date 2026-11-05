# frozen_string_literal: true

require "rails"
require "decidim/core"
require "decidim/meetings"
require "deface"

module Decidim
  module MeetingsGuestRegistrations
    # Adds guest registrations to Decidim::Meetings. It does not register a
    # component: it extends the meetings component with overrides and a few
    # routes mounted inside the meetings engine.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::MeetingsGuestRegistrations

      config.to_prepare do
        Decidim::Meetings::Meeting.prepend(Decidim::MeetingsGuestRegistrations::MeetingOverride)
        Decidim::Meetings::Registration.prepend(Decidim::MeetingsGuestRegistrations::RegistrationOverride)
      end
    end
  end
end
