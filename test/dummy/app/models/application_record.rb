class ApplicationRecord < ActiveRecord::Base
  if Rails::VERSION::MAJOR < 7
    self.abstract_class = true
  else
    primary_abstract_class
  end
end
