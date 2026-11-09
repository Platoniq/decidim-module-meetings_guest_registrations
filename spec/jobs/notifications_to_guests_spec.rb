# frozen_string_literal: true

require "spec_helper"

describe "Notifications to guests" do # rubocop:disable RSpec/DescribeClass
  let(:organization) { create(:organization) }
  let(:component) { create(:meeting_component, organization:) }
  let(:admin) { create(:user, :admin, :confirmed, organization:) }
  let(:meeting) do
    create(:meeting, :published, :with_registrations_enabled,
           component:,
           author: organization,
           start_time: 3.days.from_now,
           guest_registrations_enabled: true,
           guest_registrations_privacy_text: { en: "Privacy" })
  end
  let!(:guest) { create(:guest_registration, meeting:, email: "ana@example.org") }
  let!(:waiting_guest) { create(:guest_registration, meeting:, email: "waiting@example.org", status: :waiting_list) }

  def guest_mails
    ActionMailer::Base.deliveries.select { |mail| mail.to.intersect?(["ana@example.org", "waiting@example.org"]) }
  end

  describe Decidim::Meetings::UpcomingMeetingNotificationJob do
    it "sends the reminder to registered guests only" do
      checksum = described_class.generate_checksum(meeting)

      perform_enqueued_jobs { described_class.perform_now(meeting.id, checksum) }

      expect(guest_mails.map(&:to).flatten).to eq(["ana@example.org"])
      expect(guest_mails.first.subject).to include("Reminder")
    end
  end

  describe Decidim::Meetings::Admin::UpdateMeeting do
    let(:form) do
      Decidim::Meetings::Admin::MeetingForm.from_model(meeting).with_context(
        current_organization: organization, current_component: component, current_user: admin
      )
    end

    it "e-mails guests when the date changes" do
      form.start_time = meeting.start_time + 1.day
      form.end_time = meeting.end_time + 1.day

      perform_enqueued_jobs { described_class.call(form, meeting) }

      # The new date also schedules the reminder, which perform_enqueued_jobs runs right away.
      updates = guest_mails.select { |mail| mail.subject.include?("Meeting updated") }
      expect(updates.map(&:to).flatten).to contain_exactly("ana@example.org", "waiting@example.org")
    end

    it "does not e-mail guests while the meeting is unpublished" do
      meeting.update!(published_at: nil)
      form.start_time = meeting.start_time + 1.day
      form.end_time = meeting.end_time + 1.day

      perform_enqueued_jobs { described_class.call(form, meeting) }

      expect(guest_mails).to be_empty
    end

    it "does not e-mail guests for other changes" do
      form.title = { en: "New title" }

      perform_enqueued_jobs { described_class.call(form, meeting) }

      expect(guest_mails).to be_empty
    end
  end

  describe Decidim::Meetings::WithdrawMeeting do
    let(:author) { create(:user, :confirmed, organization:) }

    before { meeting.update!(author:) }

    it "e-mails the cancellation to guests" do
      perform_enqueued_jobs { described_class.call(meeting, author) }

      expect(guest_mails.map(&:to).flatten).to contain_exactly("ana@example.org", "waiting@example.org")
      expect(guest_mails.first.subject).to include("Meeting cancelled")
    end

    it "does not e-mail guests when the meeting is over" do
      meeting.update!(start_time: 2.days.ago, end_time: 1.day.ago)

      perform_enqueued_jobs { described_class.call(meeting, author) }

      expect(meeting.reload).to be_withdrawn
      expect(guest_mails).to be_empty
    end
  end

  describe Decidim::Meetings::Admin::UnpublishMeeting do
    it "e-mails the cancellation to guests" do
      perform_enqueued_jobs { described_class.call(meeting, admin) }

      expect(guest_mails.map(&:to).flatten).to contain_exactly("ana@example.org", "waiting@example.org")
      expect(guest_mails.first.subject).to include("Meeting cancelled")
    end

    it "deletes the guest registrations and keeps the ones of users" do
      user_registration = create(:registration, meeting:)

      described_class.call(meeting, admin)

      expect(meeting.registrations.reload).to eq([user_registration])
      expect(Decidim::MeetingsGuestRegistrations::GuestRegistration.count).to eq(0)
    end

    it "does not send the cancellation if deleting the registrations fails" do
      allow_any_instance_of(Decidim::Meetings::Registration).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed) # rubocop:disable RSpec/AnyInstance

      expect do
        Decidim::MeetingsGuestRegistrations::DiscardGuestRegistrations.call(meeting)
      end.to raise_error(ActiveRecord::RecordNotDestroyed)

      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.select { |job| job[:args].to_json.include?("meeting_cancelled") }).to be_empty
      expect(meeting.registrations.guests.count).to eq(2)
    end

    it "does not send the reminder afterwards" do
      checksum = Decidim::Meetings::UpcomingMeetingNotificationJob.generate_checksum(meeting)
      perform_enqueued_jobs { described_class.call(meeting, admin) }
      ActionMailer::Base.deliveries.clear

      perform_enqueued_jobs { Decidim::Meetings::UpcomingMeetingNotificationJob.perform_now(meeting.id, checksum) }

      expect(guest_mails).to be_empty
    end

    it "cancels the meeting for guests while the component is unpublished" do
      component.update!(published_at: nil)

      perform_enqueued_jobs { described_class.call(meeting, admin) }

      expect(guest_mails.map(&:to).flatten).to contain_exactly("ana@example.org", "waiting@example.org")
      expect(Decidim::MeetingsGuestRegistrations::GuestRegistration.count).to eq(0)
    end

    it "cancels the meeting for guests while the participatory space is unpublished" do
      meeting.participatory_space.update!(published_at: nil)

      perform_enqueued_jobs { described_class.call(meeting, admin) }

      expect(guest_mails.map(&:to).flatten).to contain_exactly("ana@example.org", "waiting@example.org")
      expect(Decidim::MeetingsGuestRegistrations::GuestRegistration.count).to eq(0)
    end

    it "keeps the guests of a meeting that is over" do
      meeting.update!(start_time: 2.days.ago, end_time: 1.day.ago)

      perform_enqueued_jobs { described_class.call(meeting, admin) }

      expect(guest_mails).to be_empty
      expect(Decidim::MeetingsGuestRegistrations::GuestRegistration.count).to eq(2)
    end

    it "does not put the guest data in clear in the job arguments" do
      described_class.call(meeting, admin)

      arguments = ActiveJob::Base.queue_adapter.enqueued_jobs.map { |job| job[:args].to_json }.join
      expect(arguments).not_to include("ana@example.org")
    end
  end

  describe Decidim::MeetingsGuestRegistrations::NotifyGuestsJob do
    it "does not send anything while the component is unpublished" do
      component.update!(published_at: nil)

      perform_enqueued_jobs { described_class.perform_now(meeting.id, "reminder") }

      expect(guest_mails).to be_empty
    end

    it "does not send anything while the participatory space is unpublished" do
      meeting.participatory_space.update!(published_at: nil)

      perform_enqueued_jobs do
        described_class.perform_now(meeting.id, "reminder")
        described_class.perform_now(meeting.id, "meeting_updated")
      end

      expect(guest_mails).to be_empty
    end

    it "sends the reminder when the meeting, component and space are published" do
      perform_enqueued_jobs { described_class.perform_now(meeting.id, "reminder") }

      expect(guest_mails.map(&:to).flatten).to eq(["ana@example.org"])
    end

    it "does not send anything for a withdrawn meeting" do
      meeting.update!(withdrawn_at: Time.current)

      perform_enqueued_jobs { described_class.perform_now(meeting.id, "reminder") }

      expect(guest_mails).to be_empty
    end
  end

  describe Decidim::Meetings::UpdateMeeting do
    let(:author) { create(:user, :confirmed, organization:) }
    let(:form) do
      Decidim::Meetings::MeetingForm.from_model(meeting).with_context(
        current_organization: organization, current_component: component, current_user: author
      )
    end

    before do
      meeting.update!(author:)
      component.update!(settings: { creation_enabled_for_participants: true })
    end

    it "e-mails guests when the participant author changes the date" do
      form.start_time = meeting.start_time + 1.day
      form.end_time = meeting.end_time + 1.day

      perform_enqueued_jobs { described_class.call(form, meeting) }

      updates = guest_mails.select { |mail| mail.subject.include?("Meeting updated") }
      expect(updates.map(&:to).flatten).to contain_exactly("ana@example.org", "waiting@example.org")
    end
  end

  describe Decidim::Commands::SoftDeleteResource do
    it "e-mails the cancellation to guests when the meeting is trashed" do
      perform_enqueued_jobs { described_class.call(meeting, admin) }

      expect(meeting.reload.deleted_at).to be_present
      expect(guest_mails.map(&:to).flatten).to contain_exactly("ana@example.org", "waiting@example.org")
    end
  end

  describe "destroying a meeting" do
    it "e-mails the cancellation to guests" do
      perform_enqueued_jobs { meeting.destroy! }

      expect(guest_mails.map(&:to).flatten).to contain_exactly("ana@example.org", "waiting@example.org")
    end

    it "does not e-mail guests when the meeting is over" do
      meeting.update!(start_time: 2.days.ago, end_time: 1.day.ago)

      perform_enqueued_jobs { meeting.destroy! }

      expect(guest_mails).to be_empty
    end
  end

  describe Decidim::Meetings::PromoteFromWaitlistJob do
    it "e-mails the promoted guest instead of notifying" do
      meeting.update!(available_slots: 10, reserved_slots: 0)

      expect(Decidim::EventsManager).not_to receive(:publish)
      perform_enqueued_jobs { described_class.perform_now(meeting.id) }

      expect(waiting_guest.registration.reload).to be_registered
      expect(guest_mails.map(&:to).flatten).to eq(["waiting@example.org"])
      expect(guest_mails.first.subject).to include("You have a place")
    end

    it "keeps notifying the promoted users" do
      waiting_guest.registration.destroy!
      user_registration = create(:registration, meeting:, status: :waiting_list)
      meeting.update!(available_slots: 10, reserved_slots: 0)

      expect(Decidim::EventsManager).to receive(:publish)
        .with(hash_including(event: "decidim.events.meetings.meeting_registration_confirmed", affected_users: [user_registration.user]))
      described_class.perform_now(meeting.id)

      expect(user_registration.reload).to be_registered
    end

    it "e-mails the promoted guest while the component is unpublished" do
      component.update!(published_at: nil)
      meeting.update!(available_slots: 10, reserved_slots: 0)

      perform_enqueued_jobs { described_class.perform_now(meeting.id) }

      expect(waiting_guest.registration.reload).to be_registered
      expect(guest_mails.map(&:to).flatten).to eq(["waiting@example.org"])
      expect(guest_mails.first.subject).to include("You have a place")
    end
  end
end
