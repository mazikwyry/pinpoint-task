# frozen_string_literal: true

require "uri"
require "net/http"
require_relative "../../lib/pinpoint_api_client"
require_relative "../../lib/hibob_integration"

class ApplicationWebhooksController < ApplicationController
  # TODO: Add verify_authenticity_token

  SUPPORTED_EVENTS = %w[application_hired].freeze

  def handle
    event = JSON.parse(request.body.read)
    event_type = event.fetch("event")

    return head(:unprocessable_entity) unless SUPPORTED_EVENTS.include?(event_type)

    application_id = event.dig("data", "application", "id")

    return head(:bad_request) unless application_id

    application = get_pinpoint_application(application_id)

    return head(:not_found) unless application

    if event_type == "application_hired"
      return handle_application_hired(event, application)
    else
      head(:unprocessable_entity)
    end
  rescue JSON::ParserError => e
    head(:bad_request)
  rescue ::PinpointApiClient::Error, ::HibobApiClient::Error => e
    head(:internal_server_error)
  end

  private

  def handle_application_hired(event, application)
    application_id = event.dig("data", "application", "id")
    errors = []

    subscribed_integrations.each do |integration|
      result = integration.handle_application_hired(application)

      if result.success && result.value
        create_pinpoint_application_comment(application_id, result.value)
      elsif !result.success
        errors << result.value
      end
    end

    head(:unprocessable_entity) if errors.any?

    head(:ok)
  end

  def get_pinpoint_application(application_id)
    pinpoint_api_client.get_application(application_id)
  end

  def create_pinpoint_application_comment(application_id, comment)
    pinpoint_api_client.create_comment_for_application(application_id, comment)
  end

  def pinpoint_api_client
    # Proposal: fetch api_key and subdomain from the Pinpoint API or dedicated database
    @pinpoint_api_client ||= ::PinpointApiClient.new(ENV["PINPOINT_API_KEY"], ENV["PINPOINT_API_SUBDOMAIN"])
  end

  def subscribed_integrations
    # Proposal: fetch list of active integrations with credentials from the Pinpoint API or dedicated database
    [
      ::HibobIntegration.new(ENV["HIBOB_API_KEY"])
    ]
  end
end
