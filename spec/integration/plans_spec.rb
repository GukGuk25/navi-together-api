# This spec file is used to test the plans model
# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Test Plan Handling' do # rubocop:disable Metrics/BlockLength
  include Rack::Test::Methods

  before do
    @req_header = { 'CONTENT_TYPE' => 'application/json' }
    clear_db
    load_seed
  end

  describe 'Getting Plans' do # rubocop:disable Metrics/BlockLength
    describe 'Getting list of plans' do # rubocop:disable Metrics/BlockLength
      before do
        @account_data = DATA[:accounts][0]
        account = Cryal::Account.create(@account_data)
        @room1 = account.add_room(DATA[:rooms][0])
        account.add_user_room(room_id: @room1.room_id, active: true)
        @room1.add_plan(DATA[:plans][0])
        @room1.add_plan(DATA[:plans][1])

        @room2 = account.add_room(DATA[:rooms][1])
        account.add_user_room(room_id: @room2.room_id, active: true)
        @room2.add_plan(DATA[:plans][2])
      end

      it 'HAPPY: should get list all plans and single plan in a certain room' do
        # Cryal::Authenticate.call(routing, json)
        credentials = { username: @account_data['username'], password: @account_data['password'] }
        post 'api/v1/auth/authentication', credentials.to_json, @req_header
        # get data from the response
        auth = JSON.parse(last_response.body)['attributes']['auth_token']
        header 'AUTHORIZATION', "Bearer #{auth}"

        get "api/v1/rooms/#{@room1.room_id}/plans"
        _(last_response.status).must_equal 200
        result = JSON.parse(last_response.body)['data']
        _(result.length).must_equal 2

        # this is for single plans
        # get_string = "api/v1/rooms/#{@room1.room_id}/plans?plan_name=#{DATA[:plans][0]['plan_name']}"
        get "api/v1/rooms/#{@room1.room_id}/plans?plan_name=#{DATA[:plans][0]['plan_name']}"
        _(last_response.status).must_equal 200
        result = JSON.parse(last_response.body)
        _(result.length).must_equal 2

        get "api/v1/rooms/#{@room2.room_id}/plans"
        _(last_response.status).must_equal 200
        result = JSON.parse(last_response.body)
        _(result.length).must_equal 2
      end

      it 'SAD: should not get plans for wrong room id' do
        credentials = { username: @account_data['username'], password: @account_data['password'] }
        post 'api/v1/auth/authentication', credentials.to_json, @req_header
        # get data from the response
        auth = JSON.parse(last_response.body)['attributes']['auth_token']
        header 'AUTHORIZATION', "Bearer #{auth}"
        get 'api/v1/rooms/12345/plans'
        _(last_response.status).must_equal 403
      end

      it 'BAD: should not process for unauthorized account' do
        header 'AUTHORIZATION', 'Bearer bad_token'
        get "api/v1/rooms/#{@room2.room_id}/plans?plan_name=SummerEscape"
        _(last_response.status).must_equal 403

        result = JSON.parse(last_response.body)
        _(result['data']).must_be_nil
      end

      it 'SECURITY: should prevent basic SQL injection targeting IDs' do
        credentials = { username: @account_data['username'], password: @account_data['password'] }
        post 'api/v1/auth/authentication', credentials.to_json, @req_header
        # get data from the response
        auth = JSON.parse(last_response.body)['attributes']['auth_token']
        header 'AUTHORIZATION', "Bearer #{auth}"
        get "api/v1/rooms/#{@room1.room_id}/plans?plan_name=1 OR 1 = 1;"
        # p "Last response body sql inject: #{last_response.body}"
        # deliberately not reporting error -- don't give attacker information
        _(last_response.status).must_equal 404
        _(last_response.body['data']).must_be_nil
      end
    end

    describe 'Creating New Plans' do # rubocop:disable Metrics/BlockLength
      before do
        clear_db
        @account_data = DATA[:accounts][0]
        account = Cryal::Account.create(@account_data)
        @req_header = { 'CONTENT_TYPE' => 'application/json' }
        @room1 = account.add_room(DATA[:rooms][0])
        account.add_user_room(room_id: @room1.room_id, active: true)

        other_user = Cryal::Account.create(DATA[:accounts][1])
        @room2 = other_user.add_room(DATA[:rooms][1])
        other_user.add_user_room(room_id: @room2.room_id, active: true)

        @plans_data = DATA[:plans][0]
      end

      it 'HAPPY: should be able to create plans in their authorized room' do
        credentials = { username: @account_data['username'], password: @account_data['password'] }
        post 'api/v1/auth/authentication', credentials.to_json, @req_header
        # get data from the response
        auth = JSON.parse(last_response.body)['attributes']['auth_token']
        headers = { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => "Bearer #{auth}" }
        package = @plans_data.clone
        body = package.to_json

        post "api/v1/rooms/#{@room1.room_id}/plans", body, headers
        _(last_response.status).must_equal 201

        # _(last_response.headers['Location'].size).must_be :>, 0

        created = JSON.parse(last_response.body)['data']
        database_plans = Cryal::Plan.first

        _(created['plan_id']).must_equal database_plans.plan_id
        _(created['plan_name']).must_equal @plans_data['plan_name']
      end

      it 'SAD: should not create plans in unauthorized room' do
        credentials = { username: @account_data['username'], password: @account_data['password'] }
        post 'api/v1/auth/authentication', credentials.to_json, @req_header
        # get data from the response
        auth = JSON.parse(last_response.body)['attributes']['auth_token']
        headers = { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => "Bearer #{auth}" }
        package = @plans_data.clone
        body = package.to_json

        post "api/v1/rooms/#{@room2.room_id}/plans", body, headers
        _(last_response.status).must_equal 403
      end

      it 'SECURITY: should not create plans with mass assignment' do
        credentials = { username: @account_data['username'], password: @account_data['password'] }
        post 'api/v1/auth/authentication', credentials.to_json, @req_header
        # get data from the response
        auth = JSON.parse(last_response.body)['attributes']['auth_token']
        headers = { 'CONTENT_TYPE' => 'application/json', 'HTTP_AUTHORIZATION' => "Bearer #{auth}" }
        package = @plans_data.clone
        package['room_name'] = @room1.room_name
        package['created_at'] = '1900-01-01'
        body = package.to_json

        post "api/v1/rooms/#{@room1.room_id}/plans", body, headers

        _(last_response.status).must_equal 400
        # _(last_response.headers['Location']).must_be_nil
      end
    end
  end
end
