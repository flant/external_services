require 'rails_helper'
require_relative '../external_services/test'

RSpec.describe Post, type: :model do
  disable_external_services

  describe_test_api object: proc { create(:post) }
end
