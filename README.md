# Decidim::MeetingsGuestRegistrations

[![Coverage Status](https://coveralls.io/repos/github/Platoniq/decidim-module-meetings_guest_registrations/badge.svg?branch=main)](https://coveralls.io/github/Platoniq/decidim-module-meetings_guest_registrations?branch=main)

Registrations to Decidim meetings for people without an account.

In the meetings that enable it, a visitor without session can register by giving their name and surname, email and phone. Signed in participants keep using the regular Decidim flow.

## How it works

- All registrations, with or without account, live in `decidim_meetings_registrations`. Capacity, waiting list, registration codes, QR, the admin list and "mark as attendee" keep working on a single table.
- Guest registrations have `decidim_user_id = NULL`. Their personal data is in `decidim_meetings_guest_registrations`, one row per registration, encrypted with `Decidim::AttributeEncryptor` (based on `secret_key_base`).
- One registration per email and meeting, enforced with a unique index on a HMAC of the normalized email (the key is derived from `secret_key_base`).
- The same person cannot take two places. A guest cannot register with the email of a user already registered to the meeting. When a signed in user joins a meeting where they registered as a guest with the same email, the user takes over that registration: it keeps its status, code and place in the waiting list, and the guest data is deleted. Guest emails are not confirmed, so rejecting the user would let anyone block them by registering their email first. Only confirmed accounts take over a guest registration.
- Guests receive e-mails in the language they used to register and in the time zone of the organization: confirmation (with `.ics`, QR if registration codes are enabled, custom content and a cancellation link), waiting list, place obtained from the waiting list, changes of date, time or place, cancellation of the meeting (withdrawn, unpublished or trashed), the reminder before the meeting (with the custom reminder message, if any) and the confirmation of their own cancellation.
- Online and hybrid meetings: registered guests get the online meeting link by e-mail (confirmation, changes and reminder), because the meeting page only shows it to signed in or registered users when its access is restricted.
- Nothing is sent about a meeting that is no longer active (unpublished, withdrawn, hidden or trashed), apart from the cancellation itself.
- While the component or the participatory space is unpublished, the changes and the reminder are not sent (the same filter Decidim applies to followers). It is taken as temporary: no cancellation is sent. The e-mails about the guest's own registration are still sent (for example, the place after leaving the waiting list), as Decidim does for users.
- Unpublishing a meeting cancels it for guests, also while its component or space is unpublished: they get the cancellation e-mail and their registrations are deleted. If the meeting is published again, they have to register again.
- The cancellation link uses `generates_token_for`; it stops working when the registration is destroyed. A registration cannot be cancelled once the meeting has started or the attendance has been validated. In a withdrawn meeting the guest can still cancel (and so delete their data), but the waiting list is not promoted.
- Jobs and e-mails are enqueued after the transaction commits. When a job has to carry guest data (the registration no longer exists), the data is encrypted with `Decidim::AttributeEncryptor`, so it is not in clear in the logs or in the queue. Name, email and phone are also filtered from the request logs.
- Guests never appear in the public list of attendees and do not count in the "Participants" statistic of the space.

## Admin

In the registrations settings of a meeting there are two new fields:

- **Allow registrations without an account** (disabled by default).
- **Data protection information**, mandatory when the option is enabled. It is shown in the guest registration form, together with the registration terms.

The option cannot be enabled when the `join` or `join_waitlist` actions require a verification available in the organization, at component or at meeting level: a guest has no account to be verified. If a verification is added later, guest registrations stop working and the registrations settings page shows a warning.

Copying a meeting copies these settings too.

The list of registrations shows the phone and the type (with or without account), and the export includes the guest data, phone, type and the registration form responses of guests.

## Installation

Add the gem to the application's Gemfile:

```ruby
gem "decidim-meetings_guest_registrations", git: "https://github.com/Platoniq/decidim-module-meetings_guest_registrations"
```

Install and run the migrations:

```bash
bundle
bin/rails decidim_meetings_guest_registrations:install:migrations
bin/rails db:migrate
```

**Rollback warning**: rolling back `ChangeRegistrationsUserNullForGuestRegistrations` deletes every guest registration, because `decidim_user_id` cannot be `NOT NULL` again while they exist.

## Overrides

Ruby classes are extended by prepending `*Override` modules in `config.to_prepare` (see `lib/decidim/meetings_guest_registrations/engine.rb`).

Views are changed with [deface](https://github.com/spree/deface), in `app/overrides/`:

- `decidim/meetings/admin/registrations/_form`: the two new fields and the warning when they have no effect.
- `decidim/meetings/admin/registrations_attendees/index`: phone and type columns, and preloading of users and guest data.

Deface does not apply to cell templates, so the module owns copies of `decidim/meetings/join_meeting_button/show.erb` and `waitlist_button.erb` (`app/cells/`). They are the core templates plus one branch that takes visitors to the guest form (marked with `Added by decidim-meetings_guest_registrations`).

The module cell path goes right before the decidim-meetings one, so an application copy of these templates wins over the module. If your application overrides them, add the guest branch to your copy:

```erb
<% elsif guest_registration_available? %>
  <%= link_to i18n_join_text, guest_registration_path, class: button_classes %>
```

Some overrides protect guest data from visitors without session, because the core looks registrations up by user and `user: nil` matches every guest:

- `Meeting#has_registration_for?(nil)` returns `false`.
- `MeetingsController#registration` returns `nil` without session, so the meeting page never shows a guest's registration code or QR.
- The `join`, `join_waitlist`, `leave` and `decline_invitation` permissions require a user, and `LeaveMeeting` does nothing without one. Otherwise a visitor could destroy a guest registration and the registration form responses of every guest.

Other code that queries `decidim_meetings_registrations` by user (other modules, application code) may need the same care.

The public guest pages are served by `Decidim::Meetings::GuestRegistrationsController`, routed inside the meetings component engine (`/meetings/:meeting_id/guest_registration`).

`spec/lib/overrides_spec.rb` keeps the MD5 of every overridden file of the Decidim gems. When it fails after a Decidim update, review the changes in the core file, update the matching override and then the checksum.

## Limitations

- The email is not confirmed: the place is booked when the form is sent. The form has an invisible captcha and one registration per email and meeting.
- Guests cannot turn their registration into an account.
- No SMS: the phone is only for the organizers.

## Testing

```bash
bundle exec rake test_app
bundle exec rspec
```

Code coverage is measured with SimpleCov (shipped with `decidim-dev`), as in Decidim: it runs when `SIMPLECOV` is set and is configured in `.simplecov`.

```bash
SIMPLECOV=true bundle exec rspec   # HTML report in coverage/index.html
```

## Linting

```bash
bundle exec rubocop
bundle exec erb_lint --lint-all   # views, cells and deface overrides
npm ci && npm run linthtml        # HTML of the same templates
```

## License

This engine is distributed under the GNU AFFERO GENERAL PUBLIC LICENSE.
