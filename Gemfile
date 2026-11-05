# frozen_string_literal: true

source "https://rubygems.org"

ruby RUBY_VERSION

gem "decidim", "~> 0.32.2"
gem "decidim-meetings_guest_registrations", path: "."

gem "bootsnap", "~> 1.23"
gem "puma", ">= 6.3.1"

group :development, :test do
  gem "byebug", "~> 13.0", platform: :mri

  gem "decidim-dev", "~> 0.32.2"
end

group :development do
  gem "faker", "~> 3.2"
  gem "letter_opener_web", "~> 3.0"
  gem "listen", "~> 3.10"
  gem "web-console", "~> 4.3"
end
