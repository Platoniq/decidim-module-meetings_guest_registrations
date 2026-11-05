# frozen_string_literal: true

require "decidim/meetings_guest_registrations/version"
require "decidim/meetings_guest_registrations/engine"

module Decidim
  # Lets people without an account register to meetings that allow it.
  module MeetingsGuestRegistrations
    autoload :EmailDigest, "decidim/meetings_guest_registrations/email_digest"
  end
end
