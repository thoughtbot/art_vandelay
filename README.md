# 🌐 Art Vandelay
[![GitHub Actions
Demo](https://github.com/thoughtbot/art_vandelay/actions/workflows/ci.yml/badge.svg)](https://github.com/thoughtbot/art_vandelay/actions/workflows/ci.yml)

Art Vandelay is an importer/exporter for Rails 7.0 and higher.

Have you ever been on a project where, out of nowhere, someone asks you to send them a CSV of data? You think to yourself, “Ok, cool. No big deal. Just gimme five minutes”, but then that five minutes turns into a few hours. Art Vandelay can help.

**At a high level, here’s what Art Vandelay can do:**

- 🕶 Automatically [filters out sensitive information](#%EF%B8%8F-configuration).
- 🔁 Export data [in batches](#exporting-in-batches).
- 📧 [Email](#artvandelayexportemail) exported data.
- 📥 [Import data](#-importing) from a CSV or JSON file.

## ✅ Installation

Add this line to your application's Gemfile:

```ruby
gem "art_vandelay"
```

And then execute:
```bash
$ bundle
```

## ⚙️ Configuration

```ruby
# config/initializers/art_vandelay.rb
ArtVandelay.setup do |config|
  config.filtered_attributes = [:credit_card, :birthday]
  config.from_address = "no-reply-export@example.com"
  config.in_batches_of = 5000
end
```
#### Default Values

|Attribute|Value|Description|
|---------|-----|-----------|
|`filtered_attributes`|`[:passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn]`|Attributes that will be automatically filtered when exported|
|`from_address`|`nil`|The email address used when sending an email of exports|
|`in_batches_of`|`10000`|The number of records that will be exported into each CSV|

## 🧰 Usage

### 📤 Exporting

Art Vandelay supports exporting CSVs and JSON files.

```ruby
ArtVandelay::Export.new(records, export_sensitive_data: false, attributes: [], in_batches_of: ArtVandelay.in_batches_of)
```

|Argument|Description|
|--------|-----------|
|`records`|An [Active Record Relation](https://api.rubyonrails.org/classes/ActiveRecord/Relation.html) or an instance of an Active Record. E.g. `User.all`, `User.first`, `User.where(...)`, `User.find_by`|
|`export_sensitive_data`|Export sensitive data. Defaults to `false`. Can be configured with `ArtVandelay.filtered_attributes`.|
|`attributes`|An array attributes to export. Default to all.|
|`in_batches_of`|The number of records that will be exported into each file. Defaults to 10,000. Can be configured with `ArtVandelay.in_batches_of`|

#### ArtVandelay::Export#csv

Returns an instance of `ArtVandelay::Export::Result`.

```ruby
result = ArtVandelay::Export.new(User.all).csv
# => #<ArtVandelay::Export::Result>

csv_exports = result.csv_exports
# => [#<CSV::Table>, #<CSV::Table>, ...]

csv = csv_exports.first.to_a
# => [["id", "email", "password", "created_at", "updated_at"], ["1", "user@example.com", "[FILTERED]", "2022-10-25 09:20:28 UTC", "2022-10-25 09:20:28 UTC"]]
```

#### ArtVandelay::Export#json

Returns an instance of `ArtVandelay::Export::Result`.

```ruby
result = ArtVandelay::Export.new(User.all).json
# => #<ArtVandelay::Export::Result>

json_exports = result.json_exports
# => [#<CSV::Table>, #<CSV::Table>, ...]

json = JSON.parse(json_exports.first)
# => [{"id"=>1, "email"=>"user@example.com", "password"=>"[FILTERED]", "created_at"=>"2022-10-25 09:20:28.123Z", "updated_at"=>"2022-10-25 09:20:28.123Z"}]
```

##### Exporting Sensitive Data

```ruby
result = ArtVandelay::Export.new(User.all, export_sensitive_data: true).csv
# => #<ArtVandelay::Export::Result>

password = result.csv_exports.first["password"]
# => ["bosco"]
```

##### Exporting Specific Attributes

```ruby
result = ArtVandelay::Export.new(User.all, attributes: [:email]).csv
# => #<ArtVandelay::Export::Result>

csv = result.csv_exports.first.to_a
# => [["email"], ["george@vandelay_industries.com"]]
```

##### Exporting in Batches

```ruby
result = ArtVandelay::Export.new(User.all, in_batches_of: 100).csv
# => #<ArtVandelay::Export::Result>

csv_size = result.csv_exports.first.size
# => 100
```

#### ArtVandelay::Export#email

Emails the recipient(s) exports as attachments.

```ruby
email(to:, from: ArtVandelay.from_address, subject: "#{model_name} export", body: "#{model_name} export")
```

|Argument|Description|
|---------|-----|
|`to`|An array of email addresses representing who should receive the email.|
|`from`|The email address of the sender.|
|`subject`|The email subject. Defaults to the following pattern: "User export"|
|`body`|The email body. Defaults to the following pattern: "User export"|
|`format`|The format of the export file. Either `:csv` or `:json`.|

```ruby
ArtVandelay::Export
  .new(User.where.not(confirmed: nil))
  .email(
    to: ["george@vandelay_industries.com", "kel_varnsen@vandelay_industries.com"],
    from: "noreply@vandelay_industries.com",
    subject: "List of confirmed users",
    body: "Here's an export of all confirmed users in our database.",
    format: :json
  )
# => ActionMailer::Base#mail: processed outbound mail in...
```

### 📥 Importing

```ruby
ArtVandelay::Import.new(model_name, **options)
```

|Argument|Description|
|--------|-----------|
|`model_name`|The name of the model being imported. E.g. `:users`, `:user`, `"users"` or `"user"`|
|`**options`|A hash of options. Available options are `rollback:`, `strip:`|

#### Options

|Option|Description|
|------|-----------|
|`rollback:`|Whether the import should rollback if any of the records fails to save.|
|`strip:`|Strips leading and trailing whitespace from all values, including headers.|

#### ArtVandelay::Import#csv

Imports records from the supplied CSV. Returns an instance of `ArtVandelay::Import::Result`.

```ruby
csv_string = CSV.generate do |csv|
  csv << ["email", "password"]
  csv << ["george@vandelay_industries.com", "bosco"]
  csv << ["kel_varnsen@vandelay_industries.com", nil]
end

result = ArtVandelay::Import.new(:users).csv(csv_string)
# => #<ArtVandelay::Import::Result>

result.rows_accepted
# => [{:row=>["george@vandelay_industries.com", "bosco"], :id=>1}]

result.rows_rejected
# => [{:row=>["kel_varnsen@vandelay_industries.com", nil], :errors=>{:password=>["can't be blank"]}}]
```

```ruby
csv(csv_string, **options)
```

|Argument|Description|
|--------|-----------|
|`csv_string`|Data in the form of a CSV string.|
|`**options`|A hash of options. Available options are `headers:` and `attributes:`|

##### Options

|Option|Description|
|------|-----------|
|`headers:`|The CSV headers. Use when the supplied CSV string does not have headers.|
|`attributes:`|The attributes the headers should map to. Useful if the headers do not match the model's attributes.|

##### Setting headers

```ruby
csv_string = CSV.generate do |csv|
  csv << ["george@vandelay_industries.com", "bosco"]
end

result = ArtVandelay::Import.new(:users).csv(csv_string, headers: [:email, :password])
# => #<ArtVandelay::Import::Result>
```

#### ArtVandelay::Import#json

Imports records from the supplied JSON. Returns an instance of `ArtVandelay::Import::Result`.

```ruby
json_string = [
  {
    email: "george@vandelay_industries.com",
    password: "bosco"
  },
  {
    email: "kel_varnsen@vanderlay_industries.com",
    password: nil
  }
].to_json

result = ArtVandelay::Import.new(:users).json(json_string)
# => #<ArtVandelay::Import::Result>

result.rows_accepted
# => [{:row=>[{"email"=>"george@vandelay_industries.com", "password"=>"bosco"}], :id=>1}]

result.rows_rejected
# => [{:row=>[{"email"=>"kel_varnsen@vandelay_industries.com", "password"=>nil}], :errors=>{:password=>["can't be blank"]}}]
```

```ruby
json(json_string, **options)
```

##### Options

|Option|Description|
|------|-----------|
|`attributes:`|The attributes the JSON object keys should map to. Useful if the headers do not match the model's attributes.|

#### Rolling back if a record fails to save

`ArtVandelay::Import.new` supports a `:rollback` keyword argument. It imports all rows as a single transaction and does not persist any records if one record fails due to an exception.

```ruby
csv_string = CSV.generate do |csv|
  csv << ["email", "password"]
  csv << ["george@vandelay_industries.com", "bosco"]
  csv << ["kel_varnsen@vandelay_industries.com", nil]
end

result = ArtVandelay::Import.new(:users, rollback: true).csv(csv_string)
# => rollback transaction
```

#### Mapping custom headers

Both `ArtVandelay::Import#csv` and `#json` support an `:attributes` keyword argument. This lets you map fields in the import document to your Active Record model's attributes.

```ruby
csv_string = CSV.generate do |csv|
  csv << ["email_address", "passcode"]
  csv << ["george@vandelay_industries.com", "bosco"]
end

result = ArtVandelay::Import.new(:users).csv(csv_string, attributes: {email_address: :email, passcode: :password})
# => #<ArtVandelay::Import::Result>
```

#### Stripping whitespace

`ArtVandelay::Import.new` supports a `:strip` keyword argument to strip whitespace from values in the import document.

```ruby
csv_string = CSV.generate do |csv|
  csv << ["email_address  ", " passcode  "]
  csv << ["  george@vandelay_industries.com  ", "  bosco  "]
end

result = ArtVandelay::Import.new(:users, strip: true).csv(csv_string, attributes: {email_address: :email, passcode: :password})
# => #<ArtVandelay::Import::Result>

result.rows_accepted
# => [{:row=>["george@vandelay_industries.com", "bosco"], :id=>1}]
```

## 🙏 Contributing

1. Run `./bin/setup`.
2. Make your changes.
3. Ensure `./bin/ci` passes.
4. Create a [pull request](https://github.com/thoughtbot/art_vandelay/compare).

## 📜 License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
