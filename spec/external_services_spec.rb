# frozen_string_literal: true

require 'rails_helper'

describe ExternalServices do
  it 'has a version number' do
    expect(ExternalServices::VERSION).not_to be_nil
  end
end
