# frozen_string_literal: true

require "rqrcode"

module Decidim
  module MeetingsGuestRegistrations
    # E-mails sent to people registered without an account. They are written
    # in the locale the guest used to register and in the time zone of the
    # organization.
    class GuestRegistrationMailer < Decidim::ApplicationMailer
      include Decidim::TranslationsHelper
      include ActionView::Helpers::SanitizeHelper
      include Decidim::ApplicationHelper

      helper Decidim::ResourceHelper
      helper Decidim::TranslationsHelper
      helper Decidim::ApplicationHelper

      helper_method :cancel_url, :online_meeting_url, :reminder_custom_message

      # Registration confirmed, either right away or after being promoted
      # from the waiting list.
      def confirmation(guest_registration_id, promoted: false)
        with_guest(guest_registration_id) do
          @promoted = promoted
          @registration_code_enabled = @meeting.component.settings.registration_code_enabled
          @qr_filename = "qr-#{@registration.code.parameterize}.png"

          add_calendar_attachment
          add_qr_code_attachment if @registration_code_enabled

          deliver(promoted ? :promoted : :confirmation)
        end
      end

      def waitlist(guest_registration_id)
        with_guest(guest_registration_id) { deliver(:waitlist) }
      end

      def meeting_updated(guest_registration_id)
        with_guest(guest_registration_id) do
          add_calendar_attachment
          deliver(:meeting_updated)
        end
      end

      def reminder(guest_registration_id)
        with_guest(guest_registration_id) do
          add_calendar_attachment
          deliver(:reminder)
        end
      end

      # The registration may not exist any more, so it receives the recipient
      # encrypted (see Recipient).
      def meeting_cancelled(meeting_id, recipient)
        with_recipient(meeting_id, recipient) { deliver(:meeting_cancelled) }
      end

      # The registration has just been destroyed, so it receives the recipient
      # encrypted (see Recipient).
      def registration_cancelled(meeting_id, recipient)
        with_recipient(meeting_id, recipient) { deliver(:registration_cancelled) }
      end

      private

      # E-mails about an existing registration are only sent while the meeting
      # is active: a guest of a cancelled meeting already got the cancellation.
      # An unpublished component or space does not stop them, so a guest
      # promoted from the waiting list meanwhile knows they have a place (as
      # users do).
      def with_guest(guest_registration_id, &)
        @guest_registration = GuestRegistration.includes(:registration, :meeting).find_by(id: guest_registration_id)
        return if @guest_registration.blank?
        return unless NotifyGuestsJob.meeting_active?(@guest_registration.meeting)

        @registration = @guest_registration.registration

        with_meeting(@guest_registration.decidim_meeting_id,
                     name: @guest_registration.name,
                     email: @guest_registration.email,
                     locale: @guest_registration.locale,
                     &)
      end

      def with_recipient(meeting_id, recipient, &)
        data = Recipient.decode(recipient)
        return if data.blank?

        with_meeting(meeting_id, **data, &)
      end

      def with_meeting(meeting_id, name:, email:, locale:)
        @meeting = Decidim::Meetings::Meeting.with_deleted.find_by(id: meeting_id)
        return if @meeting.blank? || email.blank?

        @organization = @meeting.organization
        @name = name
        @email = email
        @locator = Decidim::ResourceLocatorPresenter.new(@meeting)

        Time.use_zone(@organization.time_zone) do
          I18n.with_locale(available_locale(locale)) { yield }
        end
      end

      def deliver(kind)
        @kind = kind
        subject = I18n.t("#{kind}.subject", scope: "decidim.meetings_guest_registrations.mailer", meeting_title:)
        mail(to: email_address_with_name(@email, @name), subject:, template_name: kind.to_s)
      end

      def available_locale(locale)
        locales = @organization.available_locales.map(&:to_s)
        locales.include?(locale.to_s) ? locale : @organization.default_locale
      end

      # The subject is plain text: no HTML escaping, and no tags either.
      def meeting_title
        strip_tags(translated_attribute(@meeting.title)).squish
      end

      # Only the e-mails about an existing registration show the link.
      def cancel_url
        Decidim::EngineRouter.main_proxy(@meeting.component).cancel_meeting_guest_registration_url(
          meeting_id: @meeting.id,
          token: @guest_registration.cancellation_token,
          host: @organization.host
        )
      end

      # Guests cannot see the online meeting link in the meeting page when its
      # access is limited to registered or signed in people, so it is sent to
      # registered guests by e-mail.
      def online_meeting_url
        return if @registration.blank? || !@registration.registered?
        return unless @meeting.online? || @meeting.hybrid?

        @meeting.online_meeting_url.presence
      end

      # Same placeholders as Decidim::Meetings::UpcomingMeetingEvent.
      def reminder_custom_message
        template = translated_attribute(@meeting.reminder_message_custom_content).to_s
        return if strip_tags(template).blank?

        message = template
                  .gsub("{{meeting_title}}", ERB::Util.html_escape(meeting_title))
                  .gsub("{{before_hours}}", @meeting.send_reminders_before_hours.to_s)
        decidim_sanitize(message)
      end

      def qr_code
        @qr_code ||= RQRCode::QRCode.new(@registration.validation_code_short_link.short_url)
      end

      def add_calendar_attachment
        calendar = Icalendar::Calendar.new
        calendar.add_event(Decidim::Meetings::Calendar::MeetingToEvent.new(@meeting).event)

        attachments["meeting-calendar-info.ics"] = calendar.to_ical
      end

      def add_qr_code_attachment
        attachments[@qr_filename] = qr_code.as_png(size: 500).to_blob
      end
    end
  end
end
