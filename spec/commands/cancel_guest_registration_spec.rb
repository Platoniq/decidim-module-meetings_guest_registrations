# frozen_string_literal: true

require "spec_helper"

module Decidim::MeetingsGuestRegistrations
  describe CancelGuestRegistration do
    subject { described_class.new(guest) }

    let(:meeting) { create(:meeting, :published, :with_registrations_enabled, available_slots: 1, reserved_slots: 0) }
    let!(:guest) { create(:guest_registration, meeting:, email: "ana@example.org") }

    it "destroys the registration and the guest data" do
      expect { subject.call }.to broadcast(:ok)

      expect(meeting.registrations.count).to eq(0)
      expect(GuestRegistration.count).to eq(0)
    end

    it "sends the cancellation e-mail" do
      perform_enqueued_jobs { subject.call }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(["ana@example.org"])
      expect(mail.subject).to include("Registration cancelled")
    end

    it "deletes the guest registration form responses" do
      question = create(:questionnaire_question, questionnaire: meeting.questionnaire)
      create(:response, questionnaire: meeting.questionnaire, question:, user: nil, session_token: guest.session_token)
      create(:response, questionnaire: meeting.questionnaire, question:, user: nil, session_token: "other")

      subject.call

      expect(meeting.questionnaire.responses.pluck(:session_token)).to eq(["other"])
    end

    context "when there is someone on the waiting list" do
      let!(:waiting) { create(:guest_registration, meeting:, status: :waiting_list) }

      it "promotes them" do
        perform_enqueued_jobs { subject.call }

        expect(waiting.registration.reload).to be_registered
        expect(ActionMailer::Base.deliveries.map(&:subject)).to include(a_string_including("You have a place"))
      end

      context "when the guest who cancels is also on the waiting list" do
        subject { described_class.new(waiting) }

        it "does not promote anyone" do
          expect { subject.call }.not_to have_enqueued_job(Decidim::Meetings::PromoteFromWaitlistJob)
        end
      end
    end

    it "does not put the guest data in clear in the job arguments" do
      expect { subject.call }.to have_enqueued_mail(GuestRegistrationMailer, :registration_cancelled)

      arguments = ActiveJob::Base.queue_adapter.enqueued_jobs.map { |job| job[:args].to_json }.join
      expect(arguments).not_to include("ana@example.org")
      expect(arguments).not_to include(guest.name)
    end

    context "when the meeting has been withdrawn" do
      let!(:waiting) { create(:guest_registration, meeting:, status: :waiting_list) }

      before { meeting.update!(withdrawn_at: Time.current) }

      it "cancels without promoting the waiting list" do
        expect { subject.call }.to broadcast(:ok)

        expect(GuestRegistration.exists?(guest.id)).to be(false)
        expect(Decidim::Meetings::PromoteFromWaitlistJob).not_to have_been_enqueued
        expect(waiting.registration.reload).to be_waiting_list
      end
    end

    context "when the meeting has started" do
      before { meeting.update!(start_time: 1.hour.ago, end_time: 1.hour.from_now) }

      it "does not cancel" do
        expect { subject.call }.to broadcast(:invalid)
        expect(meeting.registrations.count).to eq(1)
      end
    end

    context "when the attendance has been validated" do
      before { guest.registration.update!(validated_at: Time.current) }

      it "does not cancel" do
        expect { subject.call }.to broadcast(:invalid)
        expect(meeting.registrations.count).to eq(1)
      end
    end

    context "without guest registration" do
      subject { described_class.new(nil) }

      it { expect { subject.call }.to broadcast(:invalid) }
    end
  end
end
