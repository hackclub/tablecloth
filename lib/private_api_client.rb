# frozen_string_literal: true

require "faraday"
require "json"
require "securerandom"

class PrivateApiClient
  BASE_URL = "https://airtable.com"

  def initialize(session_cookie:, csrf_token:)
    @session_cookie = session_cookie
    @csrf_token = csrf_token
    @conn = Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json
      f.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:146.0) Gecko/20100101 Firefox/146.0"
      f.headers["Accept"] = "*/*"
      f.headers["x-requested-with"] = "XMLHttpRequest"
      f.headers["x-airtable-inter-service-client"] = "webClient"
      f.headers["x-user-locale"] = "en"
      f.headers["x-time-zone"] = "America/New_York"
      f.headers["Cookie"] = session_cookie
    end
  end

  def get_user_details(enterprise_id:, user_id:)
    request_id = "req#{SecureRandom.alphanumeric(17)}"
    params = {
      stringifiedObjectParams: {
        userId: user_id,
        shouldIncludeDescendantEnterpriseAccounts: false
      }.to_json,
      requestId: request_id
    }

    response = @conn.get("v0.3/enterpriseAccount/#{enterprise_id}/getUserAccountDetails", params)

    raise "API error: #{response.status} - #{response.body}" unless response.success?

    data = response.body
    raise "API returned error: #{data["msg"]}" unless data["msg"] == "SUCCESS"

    pats = data.dig("data", "personalAccessTokens") || []
    email = data.dig("data", "userInfo", "email")
    state = data.dig("data", "userInfo", "state")
    { pats: pats, email: email, state: state }
  end

  def revoke_tokens(enterprise_id:, token_ids:)
    request_id = "req#{SecureRandom.alphanumeric(17)}"
    body = {
      stringifiedObjectParams: { tokenIds: token_ids }.to_json,
      requestId: request_id,
      _csrf: @csrf_token
    }

    response = @conn.post("v0.3/enterpriseAccount/#{enterprise_id}/destroyMultiplePersonalAccessTokens", body)
    raise "API error: #{response.status} - #{response.body}" unless response.success?

    data = response.body
    raise "Revoke failed: #{data["msg"]}" unless data["msg"] == "SUCCESS"

    true
  end
end
