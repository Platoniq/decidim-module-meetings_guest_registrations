# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    VERSION = "0.1.0"
    DECIDIM_VERSION = "0.32.2"
    COMPAT_DECIDIM_VERSION = [">= 0.32", "< 0.33"].freeze

    def self.version
      VERSION
    end
  end
end
