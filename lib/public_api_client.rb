# frozen_string_literal: true

require "faraday"
require "json"

class PublicApiClient
  BASE_URL = "https://api.airtable.com/v0"

  def initialize(api_key:)
    @conn = Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.response :json
      f.headers["Authorization"] = "Bearer #{api_key}"
    end
  end

  def get_enterprise(enterprise_id:)
    response = @conn.get("meta/enterpriseAccounts/#{enterprise_id}")
    raise "API error: #{response.status} - #{response.body}" unless response.success?

    response.body
  end

  def all_enterprise_user_ids(enterprise_id:)
    enterprise = get_enterprise(enterprise_id: enterprise_id)
    enterprise["userIds"] || []
  end

  def get_users(enterprise_id:, user_ids:)
    response = @conn.get("meta/enterpriseAccounts/#{enterprise_id}/users") do |req|
      req.params["id[]"] = user_ids
    end
    raise "API error: #{response.status} - #{response.body}" unless response.success?

    response.body
  end
end
