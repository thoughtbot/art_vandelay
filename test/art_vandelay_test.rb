require "test_helper"
require "csv"

class ArtVandelayTest < ActiveSupport::TestCase
  class VERSION < ArtVandelayTest
    test "it has a version number" do
      assert ArtVandelay::VERSION
    end
  end

  class Setup < ArtVandelayTest
    test "it has the correct default values" do
      filtered_attributes = ArtVandelay.filtered_attributes
      from_address = ArtVandelay.from_address

      assert_equal(
        [:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn],
        filtered_attributes
      )
      assert_nil from_address
    end
  end

  class Export < ArtVandelayTest
    include ActionMailer::TestHelper

    test "it returns a CSV::Table instance" do
      User.create!(email: "user@xample.com", password: "password")

      result = ArtVandelay::Export.new(User.all).csv

      assert_instance_of CSV::Table, result
    end

    test "it creates a CSV containing the correct data" do
      user = User.create!(email: "user@xample.com", password: "password")

      csv = ArtVandelay::Export.new(User.all).csv

      assert_equal(
        [
          ["id", "email", "password", "created_at", "updated_at"],
          [user.id.to_s, user.email.to_s, "[FILTERED]", user.created_at.to_s, user.updated_at.to_s]
        ],
        csv.to_a
      )
      assert_equal(
        ["id", "email", "password", "created_at", "updated_at"],
        csv.headers
      )
    end

    test "it controlls what data is filtered" do
      user = User.create!(email: "user@xample.com", password: "password")
      ArtVandelay.setup do |config|
        config.filtered_attributes << :email
      end

      csv = ArtVandelay::Export.new(User.all).csv

      assert_equal(
        [
          ["id", "email", "password", "created_at", "updated_at"],
          [user.id.to_s, "[FILTERED]", "[FILTERED]", user.created_at.to_s, user.updated_at.to_s]
        ],
        csv.to_a
      )
      ArtVandelay.filtered_attributes.delete(:email)
    end

    test "it allows for unfiltered exports" do
      user = User.create!(email: "user@xample.com", password: "password")

      csv = ArtVandelay::Export.new(User.all, export_sensitive_data: true).csv

      assert_equal(
        [
          ["id", "email", "password", "created_at", "updated_at"],
          [user.id.to_s, user.email.to_s, "password", user.created_at.to_s, user.updated_at.to_s]
        ],
        csv.to_a
      )
    end

    test "it controlls what attributes are exported" do
      user = User.create!(email: "user@xample.com", password: "password")

      csv = ArtVandelay::Export.new(User.all, attributes: [:id, "email"]).csv

      assert_equal(
        [
          ["id", "email"],
          [user.id.to_s, user.email.to_s]
        ],
        csv.to_a
      )
    end

    test "it emails a CSV" do
      travel_to Date.new(1989, 12, 31).beginning_of_day
      user = User.create!(email: "user@xample.com", password: "password")

      assert_emails 1 do
        ArtVandelay::Export.new(User.all).email_csv(
          to: ["recipient_1@examaple.com", "recipient_2@example.com"],
          from: "sender@example.com"
        )
      end

      email = ActionMailer::Base.deliveries.last
      csv = email.attachments.first

      assert_equal(
        ["recipient_1@examaple.com", "recipient_2@example.com"],
        email.to
      )
      assert_equal(
        [
          ["id", "email", "password", "created_at", "updated_at"],
          [user.id.to_s, user.email.to_s, "[FILTERED]", user.created_at.to_s, user.updated_at.to_s]
        ],
        CSV.parse(csv.body.raw_source)
      )
      assert_equal "user-export-1989-12-31-00-00-00-UTC.csv", csv.filename
    end

    test "it has a default subject" do
      ArtVandelay::Export.new(User.all).email_csv(
        to: ["recipient_1@examaple.com", "recipient_2@example.com"],
        from: "sender@example.com"
      )
      email = ActionMailer::Base.deliveries.last

      assert_equal "User export", email.subject
    end

    test "it can set the subject" do
      ArtVandelay::Export.new(User.all).email_csv(
        to: ["recipient_1@examaple.com", "recipient_2@example.com"],
        from: "sender@example.com",
        subject: "CUSTOM SUBJECT"
      )
      email = ActionMailer::Base.deliveries.last

      assert_equal "CUSTOM SUBJECT", email.subject
    end

    test "it can set a from address" do
      ArtVandelay::Export.new(User.all).email_csv(
        to: ["recipient_1@examaple.com", "recipient_2@example.com"],
        from: "FROM@EMAIL.COM"
      )
      email = ActionMailer::Base.deliveries.last

      assert_equal "FROM@EMAIL.COM", email.from.first
    end

    test "it can set a default from address" do
      ArtVandelay.setup do |config|
        config.from_address = "DEFAULT@EMAIL.COM"
      end
      ArtVandelay::Export.new(User.all).email_csv(
        to: ["recipient_1@examaple.com", "recipient_2@example.com"]
      )
      email = ActionMailer::Base.deliveries.last

      assert_equal "DEFAULT@EMAIL.COM", email.from.first

      ArtVandelay.from_address = nil
    end

    test "it has a default body" do
      ArtVandelay::Export.new(User.all).email_csv(
        to: ["recipient_1@examaple.com", "recipient_2@example.com"],
        from: "sender@example.com"
      )
      email = ActionMailer::Base.deliveries.last

      assert_equal "User export", email.body.raw_source
    end

    test "it can set the body" do
      ArtVandelay::Export.new(User.all).email_csv(
        to: ["recipient_1@examaple.com", "recipient_2@example.com"],
        from: "sender@example.com",
        body: "CUSTOM BODY"
      )
      email = ActionMailer::Base.deliveries.last

      assert_equal "CUSTOM BODY", email.body.raw_source
    end
  end
end
