require 'sequel'

module Cryal
    class Location < Sequel::Model
        many_to_one :track_session, optional: true
        many_to_one :user

        def to_json(*args)
        {
            location_id: location_id,
            user_id: user_id,
            cur_lat: cur_lat,
            cur_long: cur_long,
            cur_address: cur_address,
            cur_name: cur_name,
            timestamp: timestamp,
            session_id: session_id
        }.to_json(*args)
        end
    end
end
