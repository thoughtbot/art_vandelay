source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in art_vandelay.gemspec.
gemspec

# Start debugger with binding.b [https://github.com/ruby/debug]
# gem "debug", ">= 1.0.0"
#
rails_version = ENV.fetch("RAILS_VERSION", "7.0")

rails_constraint = if rails_version == "main"
  {github: "rails/rails"}
else
  "~> #{rails_version}.0"
end

if rails_version.start_with? "6"
  gem "net-imap", require: false
  gem "net-pop", require: false
  gem "net-smtp", require: false
  gem "psych", "< 4"
end
gem "rails", rails_constraint
gem "sprockets-rails"
gem "sqlite3", "~> 1.4"
gem "standardrb"
