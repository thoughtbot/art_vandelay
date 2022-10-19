require "art_vandelay/version"
require "art_vandelay/engine"
require "csv"

module ArtVandelay
  mattr_accessor :filtered_attributes, :from_address, :in_batches_of
  @@filtered_attributes = [:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn]
  @@in_batches_of = 10000

  def self.setup
    yield self
  end

  class Export
    class Result
      attr_reader :csv_exports

      def initialize(csv_exports)
        @csv_exports = csv_exports
      end
    end

    # TODO attributes: self.filtered_attributes
    def initialize(records, export_sensitive_data: false, attributes: [], in_batches_of: ArtVandelay.in_batches_of)
      @records = records
      @export_sensitive_data = export_sensitive_data
      @attributes = attributes
      @in_batches_of = in_batches_of
    end

    def csv
      csv_exports = []

      if records.is_a?(ActiveRecord::Relation)
        records.in_batches(of: in_batches_of) do |relation|
          csv_exports << CSV.parse(generate_csv(relation), headers: true)
        end
      elsif records.is_a?(ActiveRecord::Base)
        csv_exports << CSV.parse(generate_csv(records), headers: true)
      end

      Result.new(csv_exports)
    end

    def email_csv(to:, from: ArtVandelay.from_address, subject: "#{model_name} export", body: "#{model_name} export")
      mailer = ActionMailer::Base.mail(to: to, from: from, subject: subject, body: body)
      csv_exports = csv.csv_exports

      csv_exports.each.with_index(1) do |csv, index|
        if csv_exports.one?
          mailer.attachments[file_name] = csv
        else
          mailer.attachments[file_name(suffix: "-#{index}")] = csv
        end
      end

      mailer.deliver
    end

    private

    attr_reader :records, :export_sensitive_data, :attributes, :in_batches_of

    def file_name(**options)
      prefix = model_name.downcase
      timestamp = Time.current.in_time_zone("UTC").strftime("%Y-%m-%d-%H-%M-%S-UTC")
      suffix = options[:suffix]

      "#{prefix}-export-#{timestamp}#{suffix}.csv"
    end

    def filtered_values(attributes)
      if export_sensitive_data
        ActiveSupport::ParameterFilter.new([]).filter(attributes).values
      else
        ActiveSupport::ParameterFilter.new(ArtVandelay.filtered_attributes).filter(attributes).values
      end
    end

    def generate_csv(relation)
      CSV.generate do |csv|
        csv << header
        if relation.is_a?(ActiveRecord::Relation)
          relation.each do |record|
            csv << row(record.attributes)
          end
        elsif relation.is_a?(ActiveRecord::Base)
          csv << row(records.attributes)
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
