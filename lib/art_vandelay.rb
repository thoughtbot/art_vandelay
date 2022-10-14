require "art_vandelay/version"
require "art_vandelay/engine"

module ArtVandelay
  mattr_accessor :filtered_attributes
  @@filtered_attributes = [:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn]

  def self.setup
    yield self
  end

  class Export
    def initialize(records, export_sensitive_data: false, attributes: [])
      @records = records
      @export_sensitive_data = export_sensitive_data
      @attributes = attributes
    end

    def csv
      CSV.parse(generate_csv, headers: true)
    end

    private

    attr_reader :records, :export_sensitive_data, :attributes

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
      records.model_name.name.constantize
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
