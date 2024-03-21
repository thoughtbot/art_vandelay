require "test_helper"
require "csv"

class ArtVandelayTest < ActiveSupport::TestCase
  class VERSION < ArtVandelayTest
    test "it has a version number" do
      assert ArtVandelay::VERSION
    end

    test "it has a supported Rails version" do
      assert_equal ">= 7.0", ArtVandelay::RAILS_VERSION
    end

    test "it has a supported Ruby version" do
      assert_equal ">= 3.1", ArtVandelay::MINIMUM_RUBY_VERSION
    end
  end

  class Setup < ArtVandelayTest
    test "it has the correct default values" do
      filtered_attributes = ArtVandelay.filtered_attributes
      from_address = ArtVandelay.from_address
      in_batches_of = ArtVandelay.in_batches_of

      assert_equal(
        [:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn],
        filtered_attributes
      )
      assert_nil from_address
      assert_equal 10000, in_batches_of
    end
  end

  class Export < ArtVandelayTest
    include ActionMailer::TestHelper

    test "it returns a ArtVandelay::Export::Result instance" do
      User.create!(email: "user@xample.com", password: "password")

      result = ArtVandelay::Export.new(User.all).csv

      assert_instance_of ArtVandelay::Export::Result, result
    end

    test "it creates a CSV containing the correct data" do
      user = User.create!(email: "user@xample.com", password: "password")

      result = ArtVandelay::Export.new(User.all).csv
      csv = result.csv_exports.first

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

    test "it creates a CSV when passed one record" do
      user = User.create!(email: "user@xample.com", password: "password")

      result = ArtVandelay::Export.new(User.first).csv
      csv = result.csv_exports.first

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

      csv = ArtVandelay::Export.new(User.all).csv.csv_exports.first

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

      csv = ArtVandelay::Export.new(User.all, export_sensitive_data: true).csv.csv_exports.first

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

      csv = ArtVandelay::Export.new(User.all, attributes: [:id, "email"]).csv.csv_exports.first

      assert_equal(
        [
          ["id", "email"],
          [user.id.to_s, user.email.to_s]
        ],
        csv.to_a
      )
    end

    test "it batches CSV exports" do
      User.create!(email: "one@xample.com", password: "password")
      User.create!(email: "two@xample.com", password: "password")

      result = ArtVandelay::Export.new(User.all, in_batches_of: 1).csv
      csv_1 = result.csv_exports.first
      csv_2 = result.csv_exports.last

      assert "one@example.com", csv_1.first["email"]
      assert "two@example.com", csv_2.first["email"]
    end

    test "it can set the default batch size" do
      User.create!(email: "one@xample.com", password: "password")
      User.create!(email: "two@xample.com", password: "password")
      ArtVandelay.setup do |config|
        config.in_batches_of = 1
      end

      result = ArtVandelay::Export.new(User.all).csv
      csv_1 = result.csv_exports.first
      csv_2 = result.csv_exports.last

      assert "one@example.com", csv_1.first["email"]
      assert "two@example.com", csv_2.first["email"]

      ArtVandelay.in_batches_of = 10000
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

    test "it requires a from address" do
      User.create!(email: "user@xample.com", password: "password")

      assert_raises ArtVandelay::Error do
        ArtVandelay::Export.new(User.all).email_csv(
          to: ["recipient_1@examaple.com"]
        )
      end
    end

    test "it emails a CSV when one record is passed" do
      travel_to Date.new(1989, 12, 31).beginning_of_day
      user = User.create!(email: "user@xample.com", password: "password")

      assert_emails 1 do
        ArtVandelay::Export.new(User.first).email_csv(
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

    test "it emails multiple CSV attachments" do
      travel_to Date.new(1989, 12, 31).beginning_of_day
      User.create!(email: "one@example.com", password: "password")
      User.create!(email: "two@example.com", password: "password")

      assert_emails 1 do
        ArtVandelay::Export.new(User.all, in_batches_of: 1).email_csv(
          to: ["recipient_1@examaple.com"],
          from: "sender@example.com"
        )
      end

      email = ActionMailer::Base.deliveries.last
      csv_1 = email.attachments.first
      csv_2 = email.attachments.last

      assert_match "one@example.com", csv_1.body.raw_source
      assert_match "two@example.com", csv_2.body.raw_source
      assert_equal "user-export-1989-12-31-00-00-00-UTC-1.csv", csv_1.filename
      assert_equal "user-export-1989-12-31-00-00-00-UTC-2.csv", csv_2.filename
    end

    test "it raises an error if there is no data to export" do
      skip
    end

    test "it has a default subject" do
      User.create!(email: "user@xample.com", password: "password")

      ArtVandelay::Export.new(User.all).email_csv(
        to: ["recipient_1@examaple.com", "recipient_2@example.com"],
        from: "sender@example.com"
      )
      email = ActionMailer::Base.deliveries.last

      assert_equal "User export", email.subject
    end

    test "it can set the subject" do
      User.create!(email: "user@xample.com", password: "password")

      ArtVandelay::Export.new(User.all).email_csv(
        to: ["recipient_1@examaple.com", "recipient_2@example.com"],
        from: "sender@example.com",
        subject: "CUSTOM SUBJECT"
      )
      email = ActionMailer::Base.deliveries.last

      assert_equal "CUSTOM SUBJECT", email.subject
    end

    test "it can set a from address" do
      User.create!(email: "user@xample.com", password: "password")

      ArtVandelay::Export.new(User.all).email_csv(
        to: ["recipient_1@examaple.com", "recipient_2@example.com"],
        from: "FROM@EMAIL.COM"
      )
      email = ActionMailer::Base.deliveries.last

      assert_equal "FROM@EMAIL.COM", email.from.first
    end

    test "it can set a default from address" do
      User.create!(email: "user@xample.com", password: "password")
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
      User.create!(email: "user@xample.com", password: "password")
      ArtVandelay::Export.new(User.all).email_csv(
        to: ["recipient_1@examaple.com", "recipient_2@example.com"],
        from: "sender@example.com"
      )
      email = ActionMailer::Base.deliveries.last

      assert_equal "User export", email.body.raw_source
    end

    test "it can set the body" do
      User.create!(email: "user@xample.com", password: "password")
      ArtVandelay::Export.new(User.all).email_csv(
        to: ["recipient_1@examaple.com", "recipient_2@example.com"],
        from: "sender@example.com",
        body: "CUSTOM BODY"
      )
      email = ActionMailer::Base.deliveries.last

      assert_equal "CUSTOM BODY", email.body.raw_source
    end
  end

  class Import < ArtVandelayTest
    test "it imports data from a CSV string" do
      csv_string = CSV.generate do |csv|
        csv << %w[email password]
        csv << %w[email_1@example.com s3krit]
        csv << %w[email_2@example.com s3kure!]
      end

      assert_difference("User.count", 2) do
        ArtVandelay::Import.new(:users).csv(csv_string)
      end

      user_1 = User.find_by!(email: "email_1@example.com")
      user_2 = User.find_by!(email: "email_2@example.com")

      assert_equal "email_1@example.com", user_1.email
      assert_equal "s3krit", user_1.password
      assert_equal "email_2@example.com", user_2.email
      assert_equal "s3kure!", user_2.password
    end

    test "it imports data from a JSON string" do
      json_string = [
        {email: "email_1@example.com", password: "s3krit"},
        {email: "email_2@example.com", password: "s3kure!"}
      ].to_json

      assert_difference("User.count", 2) do
        ArtVandelay::Import.new(:users).json(json_string)
      end

      user_1 = User.find_by!(email: "email_1@example.com")
      user_2 = User.find_by!(email: "email_2@example.com")

      assert_equal "email_1@example.com", user_1.email
      assert_equal "s3krit", user_1.password
      assert_equal "email_2@example.com", user_2.email
      assert_equal "s3kure!", user_2.password
    end

    test "it strips whitespace from CSVs when strip configuration is passed" do
      csv_string = CSV.generate do |csv|
        csv << [" email ", "   password  "]
        csv << ["  email_1@example.com ", " s3krit "]
        csv << [" email_2@example.com ", " s3kure!  "]
      end

      assert_difference("User.count", 2) do
        ArtVandelay::Import.new(:users, strip: true).csv(csv_string)
      end

      user_1 = User.find_by!(email: "email_1@example.com")
      user_2 = User.find_by!(email: "email_2@example.com")

      assert_equal "email_1@example.com", user_1.email
      assert_equal "s3krit", user_1.password
      assert_equal "email_2@example.com", user_2.email
      assert_equal "s3kure!", user_2.password
    end

    test "it strips whitespace from JSON when strip configuration is passed" do
      json_string = [
        {email: "  email_1@example.com ", password: " s3krit "},
        {email: " email_2@example.com ", password: " s3kure!  "}
      ].to_json

      assert_difference("User.count", 2) do
        ArtVandelay::Import.new(:users, strip: true).json(json_string)
      end

      user_1 = User.find_by!(email: "email_1@example.com")
      user_2 = User.find_by!(email: "email_2@example.com")

      assert_equal "email_1@example.com", user_1.email
      assert_equal "s3krit", user_1.password
      assert_equal "email_2@example.com", user_2.email
      assert_equal "s3kure!", user_2.password
    end

    test "it sets the CSV headers" do
      csv_string = CSV.generate do |csv|
        csv << %w[email_1@example.com s3krit]
        csv << %w[email_2@example.com s3kure!]
      end

      assert_difference("User.count", 2) do
        ArtVandelay::Import.new(:users).csv(csv_string, headers: [:email, :password])
      end

      user_1 = User.find_by!(email: "email_1@example.com")
      user_2 = User.find_by!(email: "email_2@example.com")

      assert_equal "email_1@example.com", user_1.email
      assert_equal "s3krit", user_1.password
      assert_equal "email_2@example.com", user_2.email
      assert_equal "s3kure!", user_2.password
    end

    test "it maps CSV headers to Active Record attributes" do
      csv_string = CSV.generate do |csv|
        csv << %w[email_address passcode]
        csv << %w[email_1@example.com s3krit]
        csv << %w[email_2@example.com s3kure!]
      end

      assert_difference("User.count", 2) do
        ArtVandelay::Import.new(:users).csv(csv_string, attributes: {:email_address => :email, "passcode" => "password"})
      end

      user_1 = User.find_by!(email: "email_1@example.com")
      user_2 = User.find_by!(email: "email_2@example.com")

      assert_equal "email_1@example.com", user_1.email
      assert_equal "s3krit", user_1.password
      assert_equal "email_2@example.com", user_2.email
      assert_equal "s3kure!", user_2.password
    end

    test "it maps JSON keys to Active Record attributes" do
      json_string = [
        {email_address: "email_1@example.com", passcode: "s3krit"},
        {email_address: "email_2@example.com", passcode: "s3kure!"}
      ].to_json

      assert_difference("User.count", 2) do
        ArtVandelay::Import
          .new(:users)
          .json(
            json_string,
            attributes: {:email_address => :email, "passcode" => "password"}
          )
      end

      user_1 = User.find_by!(email: "email_1@example.com")
      user_2 = User.find_by!(email: "email_2@example.com")

      assert_equal "email_1@example.com", user_1.email
      assert_equal "s3krit", user_1.password
      assert_equal "email_2@example.com", user_2.email
      assert_equal "s3kure!", user_2.password
    end

    test "strips whitespace from CSVs if strip configuration is passed when using custom attributes" do
      csv_string = CSV.generate do |csv|
        csv << ["email_address ", "  passcode "]
        csv << ["  email_1@example.com ", " s3krit "]
        csv << [" email_2@example.com", "   s3kure!  "]
      end

      assert_difference("User.count", 2) do
        ArtVandelay::Import
          .new(:users, strip: true)
          .csv(csv_string, attributes: {:email_address => :email, "passcode" => "password"})
      end

      user_1 = User.find_by!(email: "email_1@example.com")
      user_2 = User.find_by!(email: "email_2@example.com")

      assert_equal "email_1@example.com", user_1.email
      assert_equal "s3krit", user_1.password
      assert_equal "email_2@example.com", user_2.email
      assert_equal "s3kure!", user_2.password
    end

    test "strips whitespace from JSON if the strip configuration is passed when using custom attributes" do
      json_string = [
        {email_address: "  email_1@example.com ", passcode: " s3krit "},
        {email_address: " email_2@example.com", passcode: "   s3kure!  "}
      ].to_json

      assert_difference("User.count", 2) do
        ArtVandelay::Import
          .new(:users, strip: true)
          .json(
            json_string,
            attributes: {:email_address => :email, "passcode" => "password"}
          )
      end

      user_1 = User.find_by!(email: "email_1@example.com")
      user_2 = User.find_by!(email: "email_2@example.com")

      assert_equal "email_1@example.com", user_1.email
      assert_equal "s3krit", user_1.password
      assert_equal "email_2@example.com", user_2.email
      assert_equal "s3kure!", user_2.password
    end

    test "it no-ops if one record fails to save and 'rollback' is enabled" do
      csv_string = CSV.generate do |csv|
        csv << %w[email password]
        csv << %w[valid@example.com s3kure!]
        csv << %w[invalid@example.com]
        csv << %w[valid@example.com s3kure!]
      end

      json_string = [
        {email: "valid@example.com", password: "s3kure!"},
        {email: "invalid@example.com"},
        {email: "invalid2@example.com", password: nil}
      ].to_json

      assert_no_difference("User.count") do
        assert_raises ActiveRecord::RecordInvalid do
          ArtVandelay::Import.new(:users, rollback: true).csv(csv_string)
        end
      end

      assert_no_difference("User.count") do
        assert_raises ActiveRecord::RecordInvalid do
          ArtVandelay::Import.new(:users, rollback: true).json(json_string)
        end
      end
    end

    test "it saves other records if another fails to save" do
      csv_string = CSV.generate do |csv|
        csv << %w[email password]
        csv << %w[valid_1@example.com s3kure!]
        csv << %w[invalid@example.com]
        csv << %w[valid_2@example.com s3kure!]
      end

      assert_difference("User.count", 2) do
        ArtVandelay::Import.new(:users).csv(csv_string)
      end

      json_string = [
        {email: "valid_3@example.com", password: "s3kure!"},
        {email: "invalid@example.com"},
        {email: "invalid2@example.com", password: nil}
      ].to_json

      assert_difference("User.count", 1) do
        ArtVandelay::Import.new(:users).json(json_string)
      end
    end

    test "returns results" do
      csv_string = CSV.generate do |csv|
        csv << %w[email password]
        csv << %w[valid_1@example.com s3krit]
        csv << %w[invalid@example.com]
        csv << %w[valid_2@example.com s3krit]
      end

      csv_result = ArtVandelay::Import.new(:users).csv(csv_string)

      assert_equal(
        [
          {
            row: ["valid_1@example.com", "s3krit"],
            id: User.find_by!(email: "valid_1@example.com").id
          },
          {
            row: ["valid_2@example.com", "s3krit"],
            id: User.find_by!(email: "valid_2@example.com").id
          }
        ],
        csv_result.rows_accepted
      )
      assert_equal(
        [
          row: ["invalid@example.com", nil],
          errors: {password: [I18n.t("errors.messages.blank")]}
        ],
        csv_result.rows_rejected
      )

      json_string = [
        {email: "valid_3@example.com", password: "s3kure!"},
        {email: "invalid@example.com"},
        {email: "invalid2@example.com", password: nil}
      ].to_json

      json_result = ArtVandelay::Import.new(:users).json(json_string)

      assert_equal(
        [
          {
            row: {"email" => "valid_3@example.com", "password" => "s3kure!"},
            id: User.find_by!(email: "valid_3@example.com").id
          }
        ],
        json_result.rows_accepted
      )

      assert_equal(
        [
          {
            row: {"email" => "invalid@example.com"},
            errors: {password: [I18n.t("errors.messages.blank")]}
          },
          {
            row: {"email" => "invalid2@example.com", "password" => nil},
            errors: {password: [I18n.t("errors.messages.blank")]}
          }
        ],
        json_result.rows_rejected
      )
    end

    test "it returns results when rollback is enabled" do
      csv_string = CSV.generate do |csv|
        csv << %w[email password]
        csv << %w[valid_1@example.com s3krit]
        csv << %w[valid_2@example.com s3krit]
      end

      csv_result = ArtVandelay::Import.new(:users, rollback: true).csv(csv_string)

      assert_equal(
        [
          {
            row: ["valid_1@example.com", "s3krit"],
            id: User.find_by!(email: "valid_1@example.com").id
          },
          {
            row: ["valid_2@example.com", "s3krit"],
            id: User.find_by!(email: "valid_2@example.com").id
          }
        ],
        csv_result.rows_accepted
      )
      assert_empty csv_result.rows_rejected

      json_string = [
        {email: "valid_3@example.com", password: "s3kure!"}
      ].to_json

      json_result =
        ArtVandelay::Import.new(:users, rollback: true).json(json_string)

      assert_equal(
        [
          {
            row: {"email" => "valid_3@example.com", "password" => "s3kure!"},
            id: User.find_by!(email: "valid_3@example.com").id
          }
        ],
        json_result.rows_accepted
      )
      assert_empty json_result.rows_rejected
    end

    test "it updates existing records" do
      # TODO: This requires more thought. We need a way to identify the
      # record(s) and declare we want to update them. This seems like it could
      # be a responsibility of a different class?
      skip
    end
  end
end
