# frozen_string_literal: true

require_relative 'init_spec'

describe 'Test Cryal API' do
  describe 'Get Root route' do
    it 'should find the root route' do
      get '/'
      _(last_response.status).must_equal 200
    end
  end
end
