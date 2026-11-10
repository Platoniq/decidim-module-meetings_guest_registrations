# frozen_string_literal: true

require "spec_helper"

describe "Guest registrations" do
  let(:organization) { create(:organization) }
  let(:participatory_space) { create(:participatory_process, :published, organization:) }
  let(:component) { create(:meeting_component, :published, participatory_space:) }
  let(:available_slots) { 10 }
  let(:meeting) do
    create(:meeting, :published, :with_registrations_enabled,
           component:,
           available_slots:,
           reserved_slots: 0,
           guest_registrations_enabled: true,
           guest_registrations_privacy_text: { en: "Privacy" })
  end
  let(:router) { Decidim::EngineRouter.main_proxy(component) }
  let(:meeting_path) { Decidim::ResourceLocatorPresenter.new(meeting).path }
  let(:params) do
    {
      guest_registration: {
        name: "Ana Guest",
        email: "ana@example.org",
        phone: "+34 600 123 456",
        privacy_agreement: "1",
        tos_agreement: "1"
      }
    }
  end

  before { host! organization.host }

  describe "POST create" do
    it "registers the guest" do
      expect { post router.meeting_guest_registration_path(meeting_id: meeting.id), params: }
        .to change(Decidim::MeetingsGuestRegistrations::GuestRegistration, :count).by(1)

      expect(response).to redirect_to(meeting_path)
    end

    it "treats a filled honeypot as spam" do
      expect { post router.meeting_guest_registration_path(meeting_id: meeting.id), params: params.merge(another_fake_attribute: "spam") }
        .not_to change(Decidim::MeetingsGuestRegistrations::GuestRegistration, :count)

      expect(response).to redirect_to(meeting_path)
      expect(flash[:alert]).to be_present
    end

    context "when the meeting is full and has no waiting list" do
      let(:available_slots) { 1 }

      before do
        create(:guest_registration, meeting:)
        allow(Decidim::Meetings).to receive(:waiting_list_enabled).and_return(false)
      end

      it "goes back to the meeting" do
        expect { post router.meeting_guest_registration_path(meeting_id: meeting.id), params: }
          .not_to change(Decidim::MeetingsGuestRegistrations::GuestRegistration, :count)

        expect(response).to redirect_to(meeting_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "DELETE destroy" do
    let!(:guest) { create(:guest_registration, meeting:) }

    it "rejects the cancellation link of another meeting" do
      other_guest = create(:guest_registration, meeting: create(:meeting, :published, :with_registrations_enabled, component:))

      expect { delete router.meeting_guest_registration_path(meeting_id: meeting.id, token: other_guest.cancellation_token) }
        .not_to change(Decidim::MeetingsGuestRegistrations::GuestRegistration, :count)

      expect(response).to redirect_to(meeting_path)
      expect(flash[:alert]).to be_present
    end

    # The meeting starts (or the attendance is validated) between the
    # permission check and the command.
    context "when the registration stops being cancellable during the request" do
      before do
        allow(Decidim::MeetingsGuestRegistrations::GuestRegistration).to receive(:find_by_token_for).and_wrap_original do |method, *args|
          method.call(*args).tap do |found|
            allow(found).to receive(:cancellable?).and_return(true, false) if found
          end
        end
      end

      it "keeps the registration and goes back to the meeting" do
        expect { delete router.meeting_guest_registration_path(meeting_id: meeting.id, token: guest.cancellation_token) }
          .not_to change(Decidim::MeetingsGuestRegistrations::GuestRegistration, :count)

        expect(response).to redirect_to(meeting_path)
        expect(flash[:alert]).to be_present
      end
    end
  end
end
