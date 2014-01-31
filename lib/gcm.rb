require 'httparty'
require 'cgi'
require 'json'

class GCM
  include HTTParty
  PUSH_URL = 'https://android.googleapis.com/gcm/send'
  base_uri PUSH_URL
  default_timeout 30
  format :json

  attr_accessor :timeout, :api_key

  def initialize(api_key, client_options = {})
    @api_key = api_key
    @client_options = client_options
  end

  # {
  #   "collapse_key": "score_update",
  #   "time_to_live": 108,
  #   "delay_while_idle": true,
  #   "registration_ids": ["4", "8", "15", "16", "23", "42"],
  #   "data" : {
  #     "score": "5x1",
  #     "time": "15:10"
  #   }
  # }
  # gcm = GCM.new(api_key)
  # gcm.send_notification({registration_ids: ["4sdsx", "8sdsd"], data: {score: "5x1"}})
  def send_notification(registration_ids, options = {})
    post_body = build_post_body(registration_ids, options)

    params = {
      :body => post_body.to_json,
      :headers => {
        'Authorization' => "key=#{@api_key}",
        'Content-Type' => 'application/json',
      }
    }
    response = self.class.post('', params.merge(@client_options))
    build_response(response, registration_ids)
  end

  private

  def build_post_body(registration_ids, options={})
    { :registration_ids => registration_ids }.merge(options)
  end

  def build_response(response, registration_ids)
    case 
      when response.code == 200
        body = response.body || {}
        { :response => 'success', :body => body, :headers => response.headers, :status_code => response.code, :canonical_ids => build_canonical_ids(body, registration_ids) }
      when response.code == 400
        { :response => 'Only applies for JSON requests. Indicates that the request could not be parsed as JSON, or it contained invalid fields.', :status_code => response.code }
      when response.code == 401
        { :response => 'There was an error authenticating the sender account.', :status_code => response.code }
      when response.code >= 500
        { :response => 'There was an internal error in the GCM server while trying to process the request.', :status_code => response.code }
    end
  end

  def build_canonical_ids(body, registration_ids)
    canonical_ids = []
    unless body.empty?
      body = JSON.parse(body)
      if body['canonical_ids'] > 0
        body['results'].each_with_index do |result, index|
          canonical_ids << { :old => registration_ids[index], :new => result['registration_id'] } if has_canonical_id?(result)
        end
      end
    end
    canonical_ids
  end

  def has_canonical_id?(result)
    !result['registration_id'].nil?
  end
end
