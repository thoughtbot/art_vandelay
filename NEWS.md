Unreleased

- Drops support for Ruby 3.0, since it is EOL.
- Drops support for Rails 6.
- Adds `Import#json`, `Export#json`, and `Export#email` (#34).

  The `#json` interface for importing and exporting JSON have been designed to work the same way they already work for the CSV interfaces. For example:

  ```ruby
  json_string = [
    {
      email: "george@vandelay_industries.com",
      password: "bosco"
    }
  ].to_json

  result = ArtVandelay::Import.new(:users).json(json_string, attributes: {email_address: :email, passcode: :password})
  ```

  `ArtVandelay::Export#email_csv` has been changed to a more-generic `ArtVandelay::Export#email` method that takes a new `:format` option. The new option defaults to `:csv` but can also be used with `:json`. Since the old `#email_csv` method no longer exists, you'll need to update your application code accordingly. For example:

  ```diff
  -ArtVandelay::Export.email_csv(to: my_email_address)
  +ArtVandelay::Export.email(to: my_email_address)
  ```

  *Benjamin Wil*

0.2.0 (June 15, 2023)

Add option that allows stripping of whitespace for all values (#19)

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

0.1.0 (December 9, 2022)

Initial release 🎉
