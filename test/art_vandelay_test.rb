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

      assert_equal(
        [:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn],
        filtered_attributes
      )
    end
  end

  class Export < ArtVandelayTest
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
  end
end
