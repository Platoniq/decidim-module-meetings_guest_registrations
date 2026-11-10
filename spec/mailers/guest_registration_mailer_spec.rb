# frozen_string_literal: true

require "spec_helper"

module Decidim::MeetingsGuestRegistrations
  describe GuestRegistrationMailer do
    let(:organization) { create(:organization, available_locales: [:en, :ca, :es]) }
    let(:component) { create(:meeting_component, organization:) }
    let(:meeting) { create(:meeting, :published, :with_registrations_enabled, component:) }
    let(:guest) { create(:guest_registration, meeting:, name: "Ana", email: "ana@example.org", locale: "es") }

    describe "#confirmation" do
      let(:mail) { described_class.confirmation(guest.id) }
      let(:html) { mail.html_part.body.decoded }

      it "is sent to the guest in their locale" do
        expect(mail.to).to eq(["ana@example.org"])
        expect(mail.subject).to include("Inscripción confirmada")
        expect(html).to include("Hola, Ana")
      end

      it "escapes the meeting title" do
        meeting.update!(title: { en: "<b>Title</b>", es: "<b>Título</b>" })

        expect(html).not_to include("<b>Título</b>")
        expect(html).to include("&lt;b&gt;Título&lt;/b&gt;")
        expect(mail.subject).to eq("Inscripción confirmada: Título")
      end

      it "includes the calendar and the cancellation link" do
        expect(mail.attachments.map(&:filename)).to include("meeting-calendar-info.ics")
        expect(CGI.unescape(html)).to include("token=#{guest.cancellation_token}")
      end

      it "does not include the QR when registration codes are disabled" do
        component.update!(settings: { registration_code_enabled: false })

        expect(mail.attachments.map(&:filename)).to eq(["meeting-calendar-info.ics"])
      end

      context "when the registration code is enabled" do
        before { component.update!(settings: { registration_code_enabled: true }) }

        it "includes the code and the QR" do
          expect(html).to include(guest.registration.code)
          expect(mail.attachments.map(&:filename)).to include("qr-#{guest.registration.code.parameterize}.png")
        end
      end

      context "when the meeting customizes the registration e-mail" do
        before { meeting.update!(customize_registration_email: true, registration_email_custom_content: { es: "Trae tu DNI" }) }

        it { expect(html).to include("Trae tu DNI") }
      end

      context "when the guest locale is not available" do
        before { guest.update!(locale: "fr") }

        it { expect(mail.subject).to include("Registration confirmed") }
      end

      context "when the component is unpublished" do
        before { component.update!(published_at: nil) }

        it { expect(mail.to).to eq(["ana@example.org"]) }
      end
    end

    describe "#reminder" do
      let(:mail) { described_class.reminder(guest.id) }
      let(:html) { mail.html_part.body.decoded }

      before do
        organization.update!(time_zone: "Madrid")
        meeting.update!(start_time: Time.utc(2030, 7, 10, 16, 0), end_time: Time.utc(2030, 7, 10, 18, 0))
      end

      it "shows the time in the organization time zone" do
        expect(html).to include("18:00")
        expect(html).not_to include("16:00")
      end

      it "includes the custom reminder message" do
        meeting.update!(reminder_message_custom_content: { es: "<p>Faltan {{before_hours}} horas</p>" }, send_reminders_before_hours: 48)

        expect(html).to include("Faltan 48 horas")
      end

      it "skips an empty custom reminder message" do
        meeting.update!(reminder_message_custom_content: { es: "<p></p>" })

        expect(html).not_to include("<div><p></p></div>")
      end

      context "when the meeting is online" do
        before { meeting.update!(type_of_meeting: :online, online_meeting_url: "https://meet.example.org/room") }

        it { expect(html).to include("https://meet.example.org/room") }
      end

      context "when the meeting is no longer published" do
        before { meeting.update!(published_at: nil) }

        it { expect(mail.message).to be_a(ActionMailer::Base::NullMail) }
      end
    end

    describe "#waitlist" do
      before { meeting.update!(type_of_meeting: :online, online_meeting_url: "https://meet.example.org/room") }

      it "does not include the online link before getting a place" do
        guest.registration.update!(status: :waiting_list)

        expect(described_class.waitlist(guest.id).body.decoded).not_to include("https://meet.example.org/room")
      end
    end

    describe "#registration_cancelled" do
      let(:mail) { described_class.registration_cancelled(meeting.id, Recipient.encode(build(:guest_registration, name: "Ana", email: "ana@example.org", locale: "ca"))) }

      it { expect(mail.subject).to include("Inscripció cancel·lada") }
    end

    context "with a tampered recipient" do
      it "does not send anything" do
        expect(described_class.registration_cancelled(meeting.id, "tampered").message).to be_a(ActionMailer::Base::NullMail)
      end
    end

    context "when the guest registration does not exist" do
      it "does not send anything" do
        expect(described_class.confirmation(0).message).to be_a(ActionMailer::Base::NullMail)
      end
    end
  end
end
