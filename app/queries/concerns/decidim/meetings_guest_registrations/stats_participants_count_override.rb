# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # Guests have no user id and must not count as a `nil` participant.
    module StatsParticipantsCountOverride
      private

      def meetings_query
        super.compact
      end
    end
  end
end
