# frozen_string_literal: true

require "spec_helper"

# The permissions already keep visitors out (see
# spec/requests/anonymous_core_registration_endpoints_spec.rb). This checks the
# second line of defence in the command itself.
describe Decidim::Meetings::LeaveMeeting do
  subject { described_class.new(meeting, user) }

  let(:meeting) { create(:meeting, :published, :with_registrations_enabled) }
  let!(:guest) { create(:guest_registration, meeting:) }

  context "without a user" do
    let(:user) { nil }

    it "does not destroy the guest registration" do
      expect { subject.call }.to broadcast(:invalid)

      expect(Decidim::Meetings::Registration.exists?(guest.registration.id)).to be(true)
    end
  end

  context "with a registered user" do
    let(:user) { create(:user, :confirmed, organization: meeting.organization) }

    before { create(:registration, meeting:, user:) }

    it "leaves the meeting and keeps the guest" do
      expect { subject.call }.to broadcast(:ok)

      expect(meeting.registrations.where(user:)).not_to exist
      expect(Decidim::Meetings::Registration.exists?(guest.registration.id)).to be(true)
    end
  end
end
