require 'spec_helper'

describe GCM do
  it "should raise an error if the api key is not provided" do
    expect {GCM.new}.to raise_error
  end

  it "should raise error if time_to_live is given" do
    # ref: http://developer.android.com/guide/google/gcm/gcm.html#send-msg
  end

  describe "sending notification" do
    let(:api_key) { 'AIzaSyB-1uEai2WiUapxCs2Q0GZYzPu7Udno5aA' }
    let(:registration_ids) { [ "42" ]}
    let(:valid_request_body) do
      { :registration_ids => registration_ids }
    end
    let(:valid_request_headers) do
      {
        "Content-Type" => 'application/json',
        "Authorization" => "key=#{api_key}"
      }
    end

    let(:stub_gcm_request) do
      stub_request(:post, GCM::PUSH_URL).with(
        :body => valid_request_body.to_json,
        :headers => valid_request_headers
      ).to_return(
        # ref: http://developer.android.com/guide/google/gcm/gcm.html#success
        :body => {},
        :headers => {},
        :status => 200
      )
    end

    let(:stub_gcm_request_with_basic_auth) do
      uri = URI.parse(GCM::PUSH_URL)
      uri.user = 'a'
      uri.password = 'b'
      stub_request(:post, uri.to_s).to_return(:body => {}, :headers => {}, :status => 200)
    end

    before(:each) do
      stub_gcm_request
      stub_gcm_request_with_basic_auth
    end

    it "should send notification using POST to GCM server" do
      gcm = GCM.new(api_key)
      gcm.send_notification(registration_ids).should eq({:response => 'success', :body => {}, :headers => {}, :status_code => 200, :canonical_ids => []})
      stub_gcm_request.should have_been_made.times(1)
    end

    it "should use basic authentication provided by options" do
      gcm = GCM.new(api_key, basic_auth: {username: 'a', password: 'b'})
      gcm.send_notification(registration_ids).should eq({:response => 'success', :body => {}, :headers => {}, :status_code => 200, :canonical_ids => []})
      stub_gcm_request_with_basic_auth.should have_been_made.times(1)
    end

    context "send notification with data" do
      let!(:stub_with_data){
        stub_request(:post, GCM::PUSH_URL).
          with(:body => "{\"registration_ids\":[\"42\"],\"data\":{\"score\":\"5x1\",\"time\":\"15:10\"}}",
               :headers => valid_request_headers ).
          to_return(:status => 200, :body => "", :headers => {})
      }
      before do
      end
      it "should send the data in a post request to gcm" do
        gcm = GCM.new(api_key)
        gcm.send_notification(registration_ids, { :data => { :score => "5x1", :time => "15:10"} })
        stub_with_data.should have_been_requested
      end
    end

    context " when send_notification responds with failure" do

      let(:mock_request_attributes) do
        {
          :body => valid_request_body.to_json,
          :headers => valid_request_headers
        }
      end

      subject { GCM.new(api_key) }

      context "on failure code 400" do
        before do
          stub_request(:post, GCM::PUSH_URL).with(
            mock_request_attributes
          ).to_return(
            # ref: http://developer.android.com/guide/google/gcm/gcm.html#success
            :body => {},
            :headers => {},
            :status => 400
          )
        end
        it "should not send notification due to 400" do
          subject.send_notification(registration_ids).should eq({
            :response => "Only applies for JSON requests. Indicates that the request could not be parsed as JSON, or it contained invalid fields.",
            :status_code => 400
          })
        end
      end

      context "on failure code 401" do
        before do
          stub_request(:post, GCM::PUSH_URL).with(
            mock_request_attributes
          ).to_return(
            # ref: http://developer.android.com/guide/google/gcm/gcm.html#success
            :body => {},
            :headers => {},
            :status => 401
          )
        end

        it "should not send notification due to 401" do
          subject.send_notification(registration_ids).should eq({
            :response => "There was an error authenticating the sender account.",
            :status_code => 401
          })
        end
      end

      context "on failure code 500" do
        before do
          stub_request(:post, GCM::PUSH_URL).with(
            mock_request_attributes
          ).to_return(
            # ref: http://developer.android.com/guide/google/gcm/gcm.html#success
            :body => {},
            :headers => {},
            :status => 500
          )
        end

        it "should not send notification due to 500" do
          subject.send_notification(registration_ids).should eq({
            :response => 'There was an internal error in the GCM server while trying to process the request.',
            :status_code => 500
          })
        end
      end

      context "on failure code 503" do
        before do
          stub_request(:post, GCM::PUSH_URL).with(
            mock_request_attributes
          ).to_return(
            # ref: http://developer.android.com/guide/google/gcm/gcm.html#success
            :body => {},
            :headers => {},
            :status => 503
          )
        end

        it "should not send notification due to 503" do
          subject.send_notification(registration_ids).should eq({
            :response => 'There was an internal error in the GCM server while trying to process the request.',
            :status_code => 503
          })
        end
      end
    end

    context " when send_notification responds canonical_ids" do

      let(:mock_request_attributes) do
        {
            :body => valid_request_body.to_json,
            :headers => valid_request_headers
        }
      end

      let(:valid_response_body_with_canonical_ids) do
        {
          :canonical_ids => 1, :results => [{:registration_id => "43", :message_id => "0:1385025861956342%572c22801bb3" }]
        }
      end

      subject { GCM.new(api_key) }


      before do
        stub_request(:post, GCM::PUSH_URL).with(
            mock_request_attributes
        ).to_return(
          # ref: http://developer.android.com/guide/google/gcm/gcm.html#success
          :body => valid_response_body_with_canonical_ids.to_json,
          :headers => {},
          :status => 200
        )
      end

      it "should contain canonical_ids" do
        response = subject.send_notification(registration_ids)

        response.should eq({
          :headers => {},
          :canonical_ids => [{:old => "42", :new => "43"}],
          :status_code => 200,
          :response => 'success',
          :body => "{\"canonical_ids\":1,\"results\":[{\"registration_id\":\"43\",\"message_id\":\"0:1385025861956342%572c22801bb3\"}]}"
        })
      end
    end
  end
end
