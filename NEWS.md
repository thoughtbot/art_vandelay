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
