# frozen_string_literal: true

require "decidim/meetings_guest_registrations/version"
require "decidim/meetings_guest_registrations/engine"

module Decidim
  # Lets people without an account register to meetings that allow it.
  module MeetingsGuestRegistrations
    autoload :EmailDigest, "decidim/meetings_guest_registrations/email_digest"
    autoload :Recipient, "decidim/meetings_guest_registrations/recipient"

    # Runs the block once every open transaction has been committed, or right
    # away when there is none. Jobs and e-mails enqueued from inside a
    # transaction could otherwise run before the commit (reading old data) or
    # run although the transaction is rolled back.
    def self.after_commit(&)
      ActiveRecord.after_all_transactions_commit(&)
    end
  end
end
