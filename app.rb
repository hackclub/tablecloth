# frozen_string_literal: true

require "sinatra"
require "json"
require "dotenv/load"
require "sentry-ruby"
require_relative "lib/private_api_client"
require_relative "lib/public_api_client"

Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [:http_logger]
  config.traces_sample_rate = 0.1
end

use Sentry::Rack::CaptureExceptions

set :port, ENV.fetch("PORT", 4567)

helpers do
  def authenticate!
    return if authorized?
    halt 401, { "Content-Type" => "application/json" }, { error: "unauthorized" }.to_json
  end

  def authorized?
    token = request.env["HTTP_AUTHORIZATION"]&.delete_prefix("Bearer ")
    token && Rack::Utils.secure_compare(token, ENV.fetch("API_TOKEN"))
  end
end

def private_client
  @private_client ||= PrivateApiClient.new(
    session_cookie: ENV.fetch("AIRTABLE_SESSION_COOKIE"),
    csrf_token: ENV.fetch("AIRTABLE_CSRF_TOKEN")
  )
end

def public_client
  @public_client ||= PublicApiClient.new(
    api_key: ENV.fetch("AIRTABLE_API_KEY")
  )
end

def enterprise_id = ENV.fetch("AIRTABLE_ENTERPRISE_ID")

post "/revoke" do
  authenticate!
  content_type :json

  begin
    body = JSON.parse(request.body.read)
    token = body["token"]

    halt 400, { error: "token required" }.to_json unless token

    whoami_conn = Faraday.new(url: "https://api.airtable.com/v0") do |f|
      f.request :json
      f.response :json
      f.headers["Authorization"] = "Bearer #{token}"
    end
    whoami_response = whoami_conn.get("meta/whoami")

    token_id = token.split(".").first
    halt 400, { error: "invalid token format" }.to_json unless token_id&.start_with?("pat")

    user_id = whoami_response.body["id"]
    user_id = whoami_response.body["createdByUserId"] if user_id&.start_with?("pat")
    users_response = public_client.get_users(enterprise_id: enterprise_id, user_ids: [user_id])
    owner_email = users_response.dig("users", 0, "email")

    begin
      private_client.revoke_tokens(enterprise_id: enterprise_id, token_ids: [token_id])
      { success: true, owner_email: }.to_json
    rescue StandardError => e
      Sentry.capture_exception(e)
      { success: true, owner_email:, status: "action_needed" }.to_json
    end
  rescue JSON::ParserError => e
    Sentry.capture_exception(e)
    halt 400, { error: "invalid JSON", success: false }.to_json
  rescue StandardError => e
    Sentry.capture_exception(e)
    halt 500, { error: e.message, success: false }.to_json
  end
end
