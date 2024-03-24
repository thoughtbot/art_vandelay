# 🌐 Art Vandelay
[![GitHub Actions
Demo](https://github.com/thoughtbot/art_vandelay/actions/workflows/ci.yml/badge.svg)](https://github.com/thoughtbot/art_vandelay/actions/workflows/ci.yml)

Art Vandelay is an importer/exporter for Rails 6.0 and higher.

Have you ever been on a project where, out of nowhere, someone asks you to send them a CSV of data? You think to yourself, “Ok, cool. No big deal. Just gimme five minutes”, but then that five minutes turns into a few hours. Art Vandelay can help. 

**At a high level, here’s what Art Vandelay can do:**

- 🕶 Automatically [filters out sensitive information](#%EF%B8%8F-configuration).
- 🔁 Export data [in batches](#exporting-in-batches).
- 📧 [Email](#artvandelayexportemail_csv) exported data.
- 📥 [Import data](#-importing) from a CSV.

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

```ruby
ArtVandelay::Export.new(records, export_sensitive_data: false, attributes: [], in_batches_of: ArtVandelay.in_batches_of)
```

|Argument|Description|
|--------|-----------|
|`records`|An [Active Record Relation](https://api.rubyonrails.org/classes/ActiveRecord/Relation.html) or an instance of an Active Record. E.g. `User.all`, `User.first`, `User.where(...)`, `User.find_by`|
|`export_sensitive_data`|Export sensitive data. Defaults to `false`. Can be configured with `ArtVandelay.filtered_attributes`.|
|`attributes`|An array attributes to export. Default to all.|
|`in_batches_of`|The number of records that will be exported into each CSV. Defaults to 10,000. Can be configured with `ArtVandelay.in_batches_of`|

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

#### ArtVandelay::Export#email_csv

Emails the recipient(s) CSV exports as attachments.

```ruby
email_csv(to:, from: ArtVandelay.from_address, subject: "#{model_name} export", body: "#{model_name} export")
```

|Argument|Description|
|---------|-----|
|`to`|An array of email addresses representing who should receive the email.|
|`from`|The email address of the sender.|
|`subject`|The email subject. Defaults to the following pattern: "User export"|
|`body`|The email body. Defaults to the following pattern: "User export"|

```ruby
ArtVandelay::Export
  .new(User.where.not(confirmed: nil))
  .email_csv(
    to: ["george@vandelay_industries.com", "kel_varnsen@vandelay_industries.com"],
    from: "noreply@vandelay_industries.com",
    subject: "List of confirmed users",
    body: "Here's an export of all confirmed users in our database."
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
|`**options`|A hash of options. Available options are `headers:`, `attributes:`, and `context:`|

#### Options

|Option|Description|
|------|-----------|
|`headers:`|The CSV headers. Use when the supplied CSV string does not have headers.|
|`attributes:`|The attributes the headers should map to. Useful if the headers do not match the model's attributes.|
|`context:`|A hash of hard-coded data that is imported in addition to the import data. This can be used to make association validations pass if an import is meant to be scoped to a specific user or account, for example.|

##### Rolling back if a record fails to save

```ruby
csv_string = CSV.generate do |csv|
  csv << ["email", "password"]
  csv << ["george@vandelay_industries.com", "bosco"]
  csv << ["kel_varnsen@vandelay_industries.com", nil]
end

result = ArtVandelay::Import.new(:users, rollback: true).csv(csv_string)
# => rollback transaction
```

##### Setting headers

```ruby
csv_string = CSV.generate do |csv|
  csv << ["george@vandelay_industries.com", "bosco"]
end

result = ArtVandelay::Import.new(:users).csv(csv_string, headers: [:email, :password])
# => #<ArtVandelay::Import::Result>
```

##### Mapping custom headers

```ruby
csv_string = CSV.generate do |csv|
  csv << ["email_address", "passcode"]
  csv << ["george@vandelay_industries.com", "bosco"]
end

result = ArtVandelay::Import.new(:users).csv(csv_string, attributes: {email_address: :email, passcode: :password})
# => #<ArtVandelay::Import::Result>
```

#### Adding context to imports

`ArtVandelay::Import#csv` supports a `:context` keyword argument. This lets you provide additional context that the import data may not contain. For example, you may wish to import all records with references to a specific user or account.

```ruby
csv_string = CSV.generate do |csv|
  csv << ["email_address", "passcode"]
  csv << ["george@vandelay_industries.com", "bosco"]
end

result = ArtVandelay::Import.new(:users).csv(
  csv_string,
  attributes: {email_address: :email, passcode: :password},
  context: {account: Account.find_by!(code: "VANDELAY_INDUSTRIES")}
)
# => #<ArtVandelay::Import::Result>
```

#### Stripping whitespace

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
