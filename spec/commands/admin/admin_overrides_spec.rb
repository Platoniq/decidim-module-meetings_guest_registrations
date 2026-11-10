# frozen_string_literal: true

require "spec_helper"

describe "Admin commands with guests" do # rubocop:disable RSpec/DescribeClass
  let(:organization) { create(:organization) }
  let(:component) { create(:meeting_component, organization:, settings: { registration_code_enabled: true }) }
  let(:meeting) { create(:meeting, :published, :with_registrations_enabled, component:) }
  let(:admin) { create(:user, :admin, :confirmed, organization:) }
  let!(:guest) { create(:guest_registration, meeting:) }
  let(:registration) { guest.registration }

  describe Decidim::Meetings::Admin::UpdateRegistrations do
    let(:form) do
      Decidim::Meetings::Admin::MeetingRegistrationsForm.from_params(
        registrations_enabled: true,
        available_slots: 10,
        reserved_slots: 0,
        registration_terms: { en: "Terms" },
        guest_registrations_enabled: true,
        guest_registrations_privacy_text: { en: "Privacy" }
      ).with_context(current_organization: organization, current_user: admin, meeting:)
    end

    it "saves the guest registration settings" do
      expect { described_class.call(form, meeting) }.to broadcast(:ok)

      expect(meeting.reload.guest_registrations_enabled).to be(true)
      expect(meeting.guest_registrations_privacy_text["en"]).to eq("Privacy")
    end

    it "disables guests when registrations are disabled" do
      meeting.update!(guest_registrations_enabled: true)
      form.registrations_enabled = false

      described_class.call(form, meeting)

      expect(meeting.reload.guest_registrations_enabled).to be(false)
    end
  end

  describe Decidim::Meetings::Admin::CopyMeeting do
    let(:form) do
      Decidim::Meetings::Admin::MeetingForm.from_model(meeting).with_context(
        current_organization: organization, current_component: component, current_user: admin
      )
    end

    before { meeting.update!(guest_registrations_enabled: true, guest_registrations_privacy_text: { en: "Privacy" }) }

    it "copies the guest registration settings" do
      described_class.call(form, meeting) do
        on(:ok) do |copy|
          expect(copy.guest_registrations_enabled).to be(true)
          expect(copy.guest_registrations_privacy_text["en"]).to eq("Privacy")
        end
        on(:invalid) { raise "invalid copy form: #{form.errors.full_messages}" }
      end
    end
  end

  describe Decidim::Meetings::Admin::MarkAsAttendee do
    it "marks the guest without notifying" do
      expect(Decidim::EventsManager).not_to receive(:publish)

      expect { described_class.call(registration) }.to broadcast(:ok)
      expect(registration.reload).to be_validated
    end

    it "keeps notifying users" do
      user_registration = create(:registration, meeting:)

      expect(Decidim::EventsManager).to receive(:publish)
        .with(hash_including(event: "decidim.events.meetings.registration_marked_as_attendee", affected_users: [user_registration.user]))

      expect { described_class.call(user_registration) }.to broadcast(:ok)
    end
  end

  describe Decidim::Meetings::Admin::ValidateRegistrationCode do
    let(:form) do
      Decidim::Meetings::Admin::ValidateRegistrationCodeForm.from_params(code: registration.code).with_context(current_organization: organization, meeting:)
    end

    it "validates the guest code without notifying" do
      expect(Decidim::EventsManager).not_to receive(:publish)

      expect { described_class.call(form, meeting) }.to broadcast(:ok)
      expect(registration.reload).to be_validated
    end

    context "with a user registration" do
      let(:user_registration) { create(:registration, meeting:) }
      let(:form) do
        Decidim::Meetings::Admin::ValidateRegistrationCodeForm.from_params(code: user_registration.code).with_context(current_organization: organization, meeting:)
      end

      it "keeps notifying the user" do
        expect(Decidim::EventsManager).to receive(:publish)
          .with(hash_including(event: "decidim.events.meetings.registration_code_validated", affected_users: [user_registration.user]))

        expect { described_class.call(form, meeting) }.to broadcast(:ok)
      end
    end
  end

  describe Decidim::Meetings::RegistrationSerializer do
    let(:user_registration) { create(:registration, meeting:) }

    it "exports guests with their data" do
      data = described_class.new(registration).serialize

      expect(data[:user]).to eq(name: guest.name, email: guest.email)
      expect(data[:phone]).to eq(guest.phone)
      expect(data[:registration_type]).to eq("guest")
    end

    it "keeps exporting users" do
      data = described_class.new(user_registration).serialize

      expect(data[:user]).to eq(name: user_registration.user.name, email: user_registration.user.email)
      expect(data[:phone]).to be_nil
      expect(data[:registration_type]).to eq("user")
    end

    it "exports the guest registration form responses" do
      question = create(:questionnaire_question, questionnaire: meeting.questionnaire)
      create(:response, questionnaire: meeting.questionnaire, question:, user: nil, session_token: guest.session_token, body: "Guest response")

      expect(described_class.new(registration).serialize[:registration_form_responses].to_s).to include("Guest response")
    end
  end

  describe Decidim::Meetings::Admin::ExportMeetingRegistrations do
    it "exports a mix of users and guests" do
      create(:registration, meeting:)

      expect { described_class.call(meeting, "CSV", admin) }.to broadcast(:ok)
    end
  end
end
