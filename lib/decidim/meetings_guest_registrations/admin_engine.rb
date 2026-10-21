# frozen_string_literal: true

module Decidim
  module MeetingsGuestRegistrations
    # This is the engine that runs on the public interface of `MeetingsGuestRegistrations`.
    class AdminEngine < ::Rails::Engine
      isolate_namespace Decidim::MeetingsGuestRegistrations::Admin

      paths["db/migrate"] = nil
      paths["lib/tasks"] = nil

      routes do
        # Add admin engine routes here
        # resources :meetings_guest_registrations do
        #   collection do
        #     resources :exports, only: [:create]
        #   end
        # end
        # root to: "meetings_guest_registrations#index"
      end

      def load_seed
        nil
      end
    end
  end
end
