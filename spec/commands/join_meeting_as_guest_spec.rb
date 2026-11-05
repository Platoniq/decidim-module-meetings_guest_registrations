# frozen_string_literal: true

require "spec_helper"

module Decidim::MeetingsGuestRegistrations
  describe JoinMeetingAsGuest do
    subject { described_class.new(meeting, form) }

    let(:organization) { create(:organization, available_locales: [:en, :ca, :es], available_authorizations: ["dummy_authorization_handler"]) }
    let(:component) { create(:meeting_component, organization:) }
    let(:available_slots) { 10 }
    let(:registration_form_enabled) { false }
    let(:meeting) do
      create(:meeting, :published, :with_registrations_enabled,
             component:,
             available_slots:,
             reserved_slots: 0,
             registration_form_enabled:,
             guest_registrations_enabled: true,
             guest_registrations_privacy_text: { en: "Privacy" })
    end
    let(:email) { "ana@example.org" }
    let(:params) do
      {
        name: "Ana Guest",
        email:,
        phone: "+34 600 123 456",
        privacy_agreement: "1",
        tos_agreement: "1"
      }
    end
    let(:form) do
      GuestRegistrationForm.from_params(params).with_context(
        current_organization: organization,
        meeting:,
        session_token: "token-123",
        ip_hash: "ip"
      )
    end

    it "creates a registered guest registration" do
      expect { subject.call }.to broadcast(:ok)

      registration = meeting.registrations.last
      expect(registration).to be_guest
      expect(registration).to be_registered
      expect(registration.public_participation).to be(false)
      expect(registration.guest_registration.name).to eq("Ana Guest")
      expect(registration.guest_registration.email).to eq("ana@example.org")
      expect(registration.guest_registration.locale).to eq("en")
      expect(registration.guest_registration.session_token).to eq("token-123")
      expect(registration.code).to be_present
    end

    it "sends the confirmation e-mail and no notification" do
      expect(Decidim::EventsManager).not_to receive(:publish).with(hash_including(event: "decidim.events.meetings.meeting_registration_confirmed"))

      perform_enqueued_jobs { subject.call }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(["ana@example.org"])
      expect(mail.subject).to include("Registration confirmed")
      expect(mail.attachments.map(&:filename)).to include("meeting-calendar-info.ics")
      expect(mail.html_part&.body&.decoded || mail.body.decoded).to include("guest_registration/cancel?token=")
    end

    it "does not follow, nor increase any score" do
      expect { subject.call }.not_to change(Decidim::Follow, :count)
    end

    context "when the email is already registered" do
      before { create(:guest_registration, meeting:, email: "ANA@example.org") }

      it "is invalid" do
        expect { subject.call }.to broadcast(:invalid_form)
        expect(form.errors[:email]).to be_present
      end
    end

    context "when the email belongs to a user account" do
      before { create(:user, :confirmed, organization:, email:) }

      it "registers as guest anyway" do
        expect { subject.call }.to broadcast(:ok)
      end
    end

    context "when the form is not valid" do
      let(:params) { super().merge(privacy_agreement: "0") }

      it { expect { subject.call }.to broadcast(:invalid_form) }
    end

    context "when the meeting does not allow guests" do
      before { meeting.update!(guest_registrations_enabled: false) }

      it { expect { subject.call }.to broadcast(:invalid) }
    end

    context "when joining requires a verification" do
      before { component.update!(permissions: { "join" => { "authorization_handlers" => { "dummy_authorization_handler" => {} } } }) }

      it { expect { subject.call }.to broadcast(:invalid) }
    end

    context "when there are no slots left" do
      let(:available_slots) { 1 }

      before { create(:guest_registration, meeting:) }

      context "and the waiting list is enabled" do
        before { allow(Decidim::Meetings).to receive(:waiting_list_enabled).and_return(true) }

        it "adds the guest to the waiting list" do
          perform_enqueued_jobs do
            expect { subject.call }.to broadcast(:ok)
          end

          expect(meeting.registrations.last).to be_waiting_list
          expect(ActionMailer::Base.deliveries.last.subject).to include("Waiting list")
        end
      end

      context "and the waiting list is disabled" do
        before { allow(Decidim::Meetings).to receive(:waiting_list_enabled).and_return(false) }

        it "does not register" do
          expect { subject.call }.to broadcast(:invalid)
          expect(meeting.registrations.count).to eq(1)
        end
      end
    end

    context "when the meeting has a registration form" do
      let(:registration_form_enabled) { true }
      let(:question) { create(:questionnaire_question, questionnaire: meeting.questionnaire, mandatory: true, question_type: :short_response) }
      let(:params) { super().merge(responses: [{ question_id: question.id, body: response_body }]) }
      let(:response_body) { "My response" }

      it "saves the responses linked with the guest session token" do
        expect { subject.call }.to broadcast(:ok)

        response = meeting.questionnaire.responses.last
        expect(response.user).to be_nil
        expect(response.session_token).to eq("token-123")
        expect(response.body).to eq("My response")
      end

      context "when a mandatory response is missing" do
        let(:response_body) { "" }

        it "does not register" do
          expect { subject.call }.to broadcast(:invalid_form)
          expect(meeting.registrations.count).to eq(0)
        end
      end
    end
  end
end
