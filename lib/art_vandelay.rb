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

  class Error < StandardError
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
      if from.nil?
        raise ArtVandelay::Error, "missing keyword: :from. Alternatively, set a value on ArtVandelay.from_address"
      end

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
      options = options.symbolize_keys
      suffix = options[:suffix]
      prefix = model_name.downcase
      timestamp = Time.current.in_time_zone("UTC").strftime("%Y-%m-%d-%H-%M-%S-UTC")

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

  class Import
    class Result
      attr_reader :rows_accepted, :rows_rejected

      def initialize(rows_accepted:, rows_rejected:)
        @rows_accepted = rows_accepted
        @rows_rejected = rows_rejected
      end
    end

    def initialize(model_name, **options)
      @options = options.symbolize_keys
      @rollback = options[:rollback]
      @strip = options[:strip]
      @model_name = model_name
    end

    def csv(csv_string, **options)
      options = options.symbolize_keys
      headers = options[:headers] || true
      attributes = options[:attributes] || {}
      rows = build_csv(csv_string, headers)

      if rollback
        # TODO: It would be nice to still return a result object during a
        # failure
        active_record.transaction do
          parse_rows(rows, attributes, raise_on_error: true)
        end
      else
        parse_rows(rows, attributes)
      end
    end

    def json(json_string, **options)
      options = options.symbolize_keys
      attributes = options[:attributes] || {}
      array = JSON.parse(json_string)

      if rollback
        active_record.transaction do
          parse_json_data(array, attributes, raise_on_error: true)
        end
      else
        parse_json_data(array, attributes)
      end
    end

    private

    attr_reader :model_name, :rollback, :strip

    def active_record
      model_name.to_s.classify.constantize
    end

    def build_csv(csv_string, headers)
      CSV.parse(csv_string, headers: headers)
    end

    def build_params(row, attributes)
      attributes = attributes.stringify_keys

      if strip
        row.to_h.stringify_keys.transform_keys do |key|
          attributes[key.strip] || key.strip
        end.tap do |new_params|
          new_params.transform_values!(&:strip)
        end
      else
        row.to_h.stringify_keys.transform_keys do |key|
          attributes[key] || key
        end
      end
    end

    def parse_json_data(array, attributes, **options)
      raise_on_error = options[:raise_on_error] || false
      result = Result.new(rows_accepted: [], rows_rejected: [])

      array.each do |entry|
        params = build_params(entry, attributes)
        record = active_record.new(params)

        if raise_on_error ? record.save! : record.save
          result.rows_accepted << {row: entry, id: record.id}
        else
          result.rows_rejected << {row: entry, errors: record.errors.messages}
        end
      end

      result
    end

    def parse_rows(rows, attributes, **options)
      options = options.symbolize_keys
      raise_on_error = options[:raise_on_error] || false
      result = Result.new(rows_accepted: [], rows_rejected: [])

      rows.each do |row|
        params = build_params(row, attributes)
        record = active_record.new(params)

        if raise_on_error ? record.save! : record.save
          result.rows_accepted << {row: row.fields, id: record.id}
        else
          result.rows_rejected << {row: row.fields, errors: record.errors.messages}
        end
      end

      result
    end
  end
end
