# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Name, email and locale of a guest, to e-mail them after their
    # registration has been destroyed.
    #
    # Job arguments are logged by Active Job and stored in the queue backend
    # (including retries and dead jobs), so the data travels encrypted with
    # Decidim::AttributeEncryptor, like in the database.
    module Recipient
      module_function

      def encode(guest_registration)
        Decidim::AttributeEncryptor.encrypt(
          ActiveSupport::JSON.encode(
            name: guest_registration.name,
            email: guest_registration.email,
            locale: guest_registration.locale
          )
        )
      end

      def decode(payload)
        data = ActiveSupport::JSON.decode(Decidim::AttributeEncryptor.decrypt(payload).to_s)
        return unless data.is_a?(Hash)

        data.symbolize_keys.slice(:name, :email, :locale)
      rescue ActiveSupport::MessageEncryptor::InvalidMessage, JSON::ParserError
        nil
      end
    end
  end
end
