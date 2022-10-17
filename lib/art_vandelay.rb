require "art_vandelay/version"
require "art_vandelay/engine"

module ArtVandelay
  mattr_accessor :filtered_attributes, :from_address
  @@filtered_attributes = [:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn]

  def self.setup
    yield self
  end

  class Export
    # TODO attributes: self.filtered_attributes
    def initialize(records, export_sensitive_data: false, attributes: [])
      @records = records
      @export_sensitive_data = export_sensitive_data
      @attributes = attributes
    end

    def csv
      CSV.parse(generate_csv, headers: true)
    end

    def email_csv(to:, from: ArtVandelay.from_address, subject: "#{model_name} export", body: "#{model_name} export")
      mailer = ActionMailer::Base.mail(to: to, from: from, subject: subject, body: body)
      mailer.attachments[file_name.to_s] = csv.to_csv

      mailer.deliver
    end

    private

    attr_reader :records, :export_sensitive_data, :attributes

    def file_name
      prefix = model_name.downcase
      timestamp = Time.current.in_time_zone("UTC").strftime("%Y-%m-%d-%H-%M-%S-UTC")

      "#{prefix}-export-#{timestamp}.csv"
    end

    def filtered_values(attributes)
      if export_sensitive_data
        ActiveSupport::ParameterFilter.new([]).filter(attributes).values
      else
        ActiveSupport::ParameterFilter.new(ArtVandelay.filtered_attributes).filter(attributes).values
      end
    end

    def generate_csv
      CSV.generate do |csv|
        csv << header
        records.each do |record|
          csv << row(record.attributes)
        end
      end
    end

    def header
      if attributes.any?
        model.attribute_names.select do |column_name|
          standardized_attributes.include?(column_name)
        end
      else
        model.attribute_names
      end
    end

    def model
      model_name.constantize
    end

    def model_name
      records.model_name.name
    end

    def row(attributes)
      if self.attributes.any?
        filtered_values(attributes.slice(*standardized_attributes))
      else
        filtered_values(attributes)
      end
    end

    def standardized_attributes
      attributes.map(&:to_s)
    end
  end
end
