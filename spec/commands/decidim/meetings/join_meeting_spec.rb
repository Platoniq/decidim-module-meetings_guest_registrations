# frozen_string_literal: true

require "spec_helper"

describe Decidim::Meetings::JoinMeeting do
  subject { described_class.new(meeting, form) }

  let(:organization) { create(:organization) }
  let(:component) { create(:meeting_component, organization:) }
  let(:registration_form_enabled) { false }
  let(:meeting) do
    create(:meeting, :published, :with_registrations_enabled,
           component:, available_slots: 10, reserved_slots: 0, registration_form_enabled:)
  end
  let(:user) { create(:user, :confirmed, organization:, email: "ana@example.org") }
  let(:form) { Decidim::Meetings::JoinMeetingForm.from_params(public_participation: true).with_context(current_user: user) }
  let!(:guest) { create(:guest_registration, meeting:, email: "ANA@example.org") }
  let(:registration) { guest.registration }

  it "takes over the guest registration" do
    expect { subject.call }.to broadcast(:ok)

    expect(meeting.registrations.count).to eq(1)
    expect(registration.reload.user).to eq(user)
    expect(registration).to be_registered
    expect(registration.public_participation).to be(true)
    expect(Decidim::MeetingsGuestRegistrations::GuestRegistration.exists?(guest.id)).to be(false)
  end

  it "keeps the registration code" do
    expect { subject.call }.not_to(change { registration.reload.code })
  end

  it "notifies and follows like the core" do
    allow(Decidim::EventsManager).to receive(:publish).and_call_original
    expect(Decidim::EventsManager).to receive(:publish)
      .with(hash_including(event: "decidim.events.meetings.meeting_registration_confirmed", affected_users: [user]))
    expect(Decidim::Meetings::RegistrationMailer).to receive(:confirmation).with(user, meeting, registration).and_call_original

    subject.call

    expect(Decidim::Follow.where(user:, followable: meeting)).to exist
  end

  context "when the guest is in the waiting list" do
    let!(:guest) { create(:guest_registration, meeting:, email: "ana@example.org", status: :waiting_list) }

    it "keeps the place in the waiting list" do
      allow(Decidim::EventsManager).to receive(:publish).and_call_original
      expect(Decidim::EventsManager).to receive(:publish).with(hash_including(event: "decidim.events.meetings.meeting_waitlist_added"))

      expect { subject.call }.to broadcast(:ok)
      expect(registration.reload).to be_waiting_list
    end
  end

  context "when the meeting has a registration form" do
    let(:registration_form_enabled) { true }
    let(:question) { create(:questionnaire_question, questionnaire: meeting.questionnaire, mandatory: true, question_type: :short_response) }
    let(:form) do
      Decidim::Forms::QuestionnaireForm.from_params(public_participation: false, tos_agreement: "1", responses: [{ question_id: question.id, body: response_body }])
                                       .with_context(current_user: user, session_token: "user-token")
    end
    let(:response_body) { "User response" }

    before { create(:response, questionnaire: meeting.questionnaire, question:, user: nil, session_token: guest.session_token, body: "Guest response") }

    it "replaces the guest responses with the user ones" do
      expect { subject.call }.to broadcast(:ok)

      expect(meeting.questionnaire.responses.map(&:body)).to eq(["User response"])
      expect(meeting.questionnaire.responses.first.user).to eq(user)
    end

    context "when the responses are not valid" do
      let(:response_body) { "" }

      it "keeps the guest registration and responses" do
        expect { subject.call }.to broadcast(:invalid_form)

        expect(registration.reload).to be_guest
        expect(meeting.questionnaire.responses.map(&:body)).to eq(["Guest response"])
      end
    end
  end

  context "when the guest email is a different one" do
    let!(:guest) { create(:guest_registration, meeting:, email: "other@example.org") }

    it "registers the user in a new slot" do
      expect { subject.call }.to broadcast(:ok)
      expect(meeting.registrations.count).to eq(2)
      expect(registration.reload).to be_guest
    end
  end

  context "when the user is not confirmed" do
    let(:user) { create(:user, organization:, email: "ana@example.org") }

    it "does not take over the guest registration" do
      expect { subject.call }.to broadcast(:ok)
      expect(registration.reload).to be_guest
    end
  end
end
