class Post < ApplicationRecord
  has_external_service :test

  def to_test_api
    attributes.slice('name', 'value')
  end
end
