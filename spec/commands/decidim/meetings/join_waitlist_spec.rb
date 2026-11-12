# frozen_string_literal: true

require "spec_helper"

describe Decidim::Meetings::JoinWaitlist do
  subject { described_class.new(meeting, form) }

  let(:meeting) { create(:meeting, :published, :with_registrations_enabled, available_slots: 1, reserved_slots: 0) }
  let(:user) { create(:user, :confirmed, organization: meeting.organization, email: "ana@example.org") }
  let(:form) { Decidim::Meetings::JoinMeetingForm.from_params(public_participation: false).with_context(current_user: user) }
  let!(:guest) { create(:guest_registration, meeting:, email: "ana@example.org") }

  before { allow(Decidim::Meetings).to receive(:waiting_list_enabled).and_return(true) }

  # The guest holds the only slot, so the user is offered the waiting list.
  it "takes over the slot of the guest" do
    expect { subject.call }.to broadcast(:ok)

    expect(meeting.registrations.count).to eq(1)
    expect(guest.registration.reload.user).to eq(user)
    expect(guest.registration).to be_registered
  end
end
