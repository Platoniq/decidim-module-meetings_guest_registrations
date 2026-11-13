# frozen_string_literal: true

require "spec_helper"

module Decidim::MeetingsGuestRegistrations
  describe JoinMeetingAsGuest do
    include_context "with concurrency"

    let(:organization) { create(:organization) }
    let(:component) { create(:meeting_component, organization:) }
    let!(:meeting) do
      create(:meeting, :published, :with_registrations_enabled,
             component:,
             available_slots: 1,
             reserved_slots: 0,
             registration_form_enabled: false,
             guest_registrations_enabled: true,
             guest_registrations_privacy_text: { en: "Privacy" })
    end

    before { allow(Decidim::Meetings).to receive(:waiting_list_enabled).and_return(false) }

    def join(email)
      ActiveRecord::Base.connection_pool.with_connection do
        own_meeting = Decidim::Meetings::Meeting.find(meeting.id)
        form = GuestRegistrationForm.from_params(
          name: "Guest", email:, phone: "600123456", privacy_agreement: "1", tos_agreement: "1"
        ).with_context(current_organization: organization, meeting: own_meeting, session_token: SecureRandom.hex(8), ip_hash: "ip")

        described_class.call(own_meeting, form)
      end
    end

    it "gives the last slot to only one guest" do
      threads = Array.new(4) { |index| Thread.new { join("guest#{index}@example.org") } }
      threads.each(&:join)

      expect(meeting.registrations.count).to eq(1)
    end

    it "registers the same email only once" do
      meeting.update!(available_slots: 10)

      threads = Array.new(4) { Thread.new { join("same@example.org") } }
      threads.each(&:join)

      expect(meeting.registrations.count).to eq(1)
    end
  end
end
