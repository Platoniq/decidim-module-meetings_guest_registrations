# frozen_string_literal: true

class AddGuestRegistrationsToMeetings < ActiveRecord::Migration[8.1]
  def change
    add_column :decidim_meetings_meetings, :guest_registrations_enabled, :boolean, default: false, null: false
    add_column :decidim_meetings_meetings, :guest_registrations_privacy_text, :jsonb
  end
end
