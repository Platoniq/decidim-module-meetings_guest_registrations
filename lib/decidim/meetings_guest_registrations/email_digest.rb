# frozen_string_literal: true

require "openssl"

module Decidim
  module MeetingsGuestRegistrations
    # Keyed hash of a normalized email. It lets the database enforce one
    # registration per email and meeting without storing the email in clear.
    # The key is derived from `secret_key_base`, so a plain SHA of a known
    # email cannot be matched against the stored digests.
    module EmailDigest
      KEY_SALT = "decidim-meetings-guest-registrations email digest"

      module_function

      def normalize(email)
        email.to_s.strip.downcase
      end

      def call(email)
        normalized = normalize(email)
        return if normalized.blank?

        OpenSSL::HMAC.hexdigest("SHA256", key, normalized)
      end

      def key
        Rails.application.key_generator.generate_key(KEY_SALT, 32)
      end
    end
  end
end
