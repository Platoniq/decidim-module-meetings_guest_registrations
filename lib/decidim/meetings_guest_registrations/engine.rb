# frozen_string_literal: true

require "rails"
require "decidim/core"
require "decidim/meetings"
require "deface"

module Decidim
  module MeetingsGuestRegistrations
    # Adds guest registrations to Decidim::Meetings. It does not register a
    # component: it extends the meetings component with overrides and a few
    # routes mounted inside the meetings engine.
    class Engine < ::Rails::Engine
      isolate_namespace Decidim::MeetingsGuestRegistrations

      # Routes live inside the meetings component engine so the guest pages
      # get the same component context (space, component, layout) as the
      # meeting page.
      initializer "decidim_meetings_guest_registrations.routes", before: :add_routing_paths do
        Decidim::Meetings::Engine.routes.prepend do
          resources :meetings, only: [] do
            resource :guest_registration, only: [:new, :create, :destroy] do
              get :cancel
            end
          end
        end
      end

      # Our cell templates must win over the ones in decidim-meetings, but not
      # over the application ones: the path goes right before the meetings one.
      initializer "decidim_meetings_guest_registrations.cells_view_paths", after: "decidim_meetings.add_cells_view_paths" do
        paths = Cell::ViewModel.view_paths
        meetings_path = File.expand_path("app/cells", Decidim::Meetings::Engine.root)
        index = paths.index { |path| path.to_s == meetings_path } || paths.size
        paths.insert(index, File.expand_path("app/cells", root))
      end

      # Keep the personal data of guests out of the request logs.
      initializer "decidim_meetings_guest_registrations.filter_parameters" do |app|
        app.config.filter_parameters += %w(guest_registration.name guest_registration.email guest_registration.phone)
      end

      config.to_prepare do
        Decidim::Meetings::Meeting.prepend(Decidim::MeetingsGuestRegistrations::MeetingOverride)
        Decidim::Meetings::Registration.prepend(Decidim::MeetingsGuestRegistrations::RegistrationOverride)

        Decidim::Meetings::Admin::MeetingRegistrationsForm.prepend(Decidim::MeetingsGuestRegistrations::Admin::MeetingRegistrationsFormOverride)
        Decidim::Meetings::Admin::UpdateRegistrations.prepend(Decidim::MeetingsGuestRegistrations::Admin::UpdateRegistrationsOverride)
        Decidim::Meetings::Admin::MarkAsAttendee.prepend(Decidim::MeetingsGuestRegistrations::Admin::MarkAsAttendeeOverride)
        Decidim::Meetings::Admin::ValidateRegistrationCode.prepend(Decidim::MeetingsGuestRegistrations::Admin::ValidateRegistrationCodeOverride)
        Decidim::Meetings::Admin::UpdateMeeting.prepend(Decidim::MeetingsGuestRegistrations::NotifyGuestsOnUpdateOverride)
        Decidim::Meetings::Admin::UnpublishMeeting.prepend(Decidim::MeetingsGuestRegistrations::Admin::UnpublishMeetingOverride)
        Decidim::Meetings::Admin::CopyMeeting.prepend(Decidim::MeetingsGuestRegistrations::Admin::CopyMeetingOverride)
        Decidim::Meetings::UpdateMeeting.prepend(Decidim::MeetingsGuestRegistrations::NotifyGuestsOnUpdateOverride)
        Decidim::Meetings::JoinMeeting.prepend(Decidim::MeetingsGuestRegistrations::ClaimGuestRegistrationOverride)
        Decidim::Meetings::JoinWaitlist.prepend(Decidim::MeetingsGuestRegistrations::ClaimGuestRegistrationOverride)
        Decidim::Meetings::LeaveMeeting.prepend(Decidim::MeetingsGuestRegistrations::LeaveMeetingOverride)
        Decidim::Meetings::WithdrawMeeting.prepend(Decidim::MeetingsGuestRegistrations::WithdrawMeetingOverride)

        Decidim::Meetings::PromoteFromWaitlistJob.prepend(Decidim::MeetingsGuestRegistrations::PromoteFromWaitlistJobOverride)
        Decidim::Meetings::UpcomingMeetingNotificationJob.prepend(Decidim::MeetingsGuestRegistrations::UpcomingMeetingNotificationJobOverride)

        Decidim::Meetings::RegistrationPresenter.prepend(Decidim::MeetingsGuestRegistrations::RegistrationPresenterOverride)
        Decidim::Meetings::RegistrationSerializer.prepend(Decidim::MeetingsGuestRegistrations::RegistrationSerializerOverride)
        Decidim::Meetings::MeetingPermissions.prepend(Decidim::MeetingsGuestRegistrations::MeetingPermissionsOverride)
        Decidim::Meetings::MeetingsController.prepend(Decidim::MeetingsGuestRegistrations::MeetingsControllerOverride)
        Decidim::Meetings::JoinMeetingButtonCell.prepend(Decidim::MeetingsGuestRegistrations::JoinMeetingButtonCellOverride)

        Decidim::StatsParticipantsCount.prepend(Decidim::MeetingsGuestRegistrations::StatsParticipantsCountOverride)
      end
    end
  end
end
