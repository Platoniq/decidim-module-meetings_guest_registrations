# frozen_string_literal: true

module Decidim
  module Meetings
    # Added by decidim-meetings_guest_registrations.
    #
    # Public pages to register to a meeting without an account and to cancel
    # that registration from the link sent by e-mail.
    #
    # It lives in the Decidim::Meetings namespace and is routed inside the
    # meetings component engine, so it gets the meetings route helpers and the
    # component and participatory space context of the meeting.
    class GuestRegistrationsController < Decidim::Meetings::ApplicationController
      include Decidim::FormFactory

      helper Decidim::Forms::ApplicationHelper
      helper Decidim::Meetings::MeetingsHelper

      helper_method :meeting, :guest_registration, :questionnaire, :questionnaire_required?

      invisible_captcha only: [:create], on_spam: :spam_detected

      before_action :redirect_signed_in_users, only: [:new, :create]
      before_action :ensure_guest_registration_token, only: [:cancel, :destroy]

      def new
        enforce_permission_to(:join_as_guest, :meeting, meeting:)

        @form = build_form
      end

      def create
        enforce_permission_to(:join_as_guest, :meeting, meeting:)

        @form = form(Decidim::MeetingsGuestRegistrations::GuestRegistrationForm).from_params(params, meeting:, session_token: new_session_token, ip_hash:)

        Decidim::MeetingsGuestRegistrations::JoinMeetingAsGuest.call(meeting, @form) do
          # i18n-tasks-use t("decidim.meetings_guest_registrations.guest_registrations.create.success")
          # i18n-tasks-use t("decidim.meetings_guest_registrations.guest_registrations.create.waitlist_success")
          on(:ok) do |registration|
            flash[:notice] = I18n.t(registration.registered? ? "success" : "waitlist_success", scope: "decidim.meetings_guest_registrations.guest_registrations.create")
            redirect_to meeting_path
          end

          on(:invalid_form) do
            flash.now[:alert] = I18n.t("invalid_form", scope: "decidim.meetings_guest_registrations.guest_registrations.create")
            render action: "new", status: :unprocessable_content
          end

          on(:invalid) do
            flash[:alert] = I18n.t("invalid", scope: "decidim.meetings_guest_registrations.guest_registrations.create")
            redirect_to meeting_path
          end
        end
      end

      # The signed token in the link is the credential of the guest.
      def cancel
        enforce_permission_to(:cancel_guest_registration, :meeting, meeting:, guest_registration:)
      end

      def destroy
        enforce_permission_to(:cancel_guest_registration, :meeting, meeting:, guest_registration:)

        Decidim::MeetingsGuestRegistrations::CancelGuestRegistration.call(guest_registration) do
          on(:ok) do
            flash[:notice] = I18n.t("success", scope: "decidim.meetings_guest_registrations.guest_registrations.destroy")
            redirect_to meeting_path
          end

          on(:invalid) do
            flash[:alert] = I18n.t("invalid", scope: "decidim.meetings_guest_registrations.guest_registrations.destroy")
            redirect_to meeting_path
          end
        end
      end

      private

      def meeting
        @meeting ||= Decidim::Meetings::Meeting.not_hidden.published.where(component: current_component).find(params[:meeting_id])
      end

      def meeting_path
        Decidim::ResourceLocatorPresenter.new(meeting).path
      end

      def questionnaire
        @questionnaire ||= meeting.questionnaire
      end

      def questionnaire_required?
        meeting.registration_form_enabled? && questionnaire.present? && questionnaire.questions.any?
      end

      def build_form
        return form(Decidim::MeetingsGuestRegistrations::GuestRegistrationForm).from_model(questionnaire).with_context(meeting:) if questionnaire_required?

        form(Decidim::MeetingsGuestRegistrations::GuestRegistrationForm).instance(meeting:)
      end

      def guest_registration
        return @guest_registration if defined?(@guest_registration)

        @guest_registration = Decidim::MeetingsGuestRegistrations::GuestRegistration.find_by_token_for(:guest_cancellation, params[:token].to_s)
        @guest_registration = nil if @guest_registration && @guest_registration.decidim_meeting_id != meeting.id
        @guest_registration
      end

      def ensure_guest_registration_token
        return if guest_registration.present?

        flash[:alert] = I18n.t("invalid_token", scope: "decidim.meetings_guest_registrations.guest_registrations.cancel")
        redirect_to meeting_path
      end

      # People with a session use the regular Decidim flow.
      def redirect_signed_in_users
        return unless user_signed_in?

        redirect_to meeting_path
      end

      # Decidim sends visitors without permission to the login page. Guests have
      # no account, so they go back to the meeting with an explanation.
      #
      # i18n-tasks-use t("decidim.meetings_guest_registrations.guest_registrations.not_allowed.cancel")
      # i18n-tasks-use t("decidim.meetings_guest_registrations.guest_registrations.not_allowed.create")
      # i18n-tasks-use t("decidim.meetings_guest_registrations.guest_registrations.not_allowed.destroy")
      # i18n-tasks-use t("decidim.meetings_guest_registrations.guest_registrations.not_allowed.new")
      def user_has_no_permission
        flash[:alert] = I18n.t(action_name, scope: "decidim.meetings_guest_registrations.guest_registrations.not_allowed")
        redirect_to meeting_path
      end

      def spam_detected
        flash[:alert] = I18n.t("invalid", scope: "decidim.meetings_guest_registrations.guest_registrations.create")
        redirect_to meeting_path
      end

      # Every guest gets its own token to link the registration form
      # responses with the registration.
      def new_session_token
        @new_session_token ||= SecureRandom.hex(16)
      end

      def ip_hash
        return if request.remote_ip.blank? || questionnaire.blank?

        Decidim::Tokenizer.new(salt: questionnaire.salt || questionnaire.id, length: 10).int_digest(request.remote_ip).to_s
      end
    end
  end
end
