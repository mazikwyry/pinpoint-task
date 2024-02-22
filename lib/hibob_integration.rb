# frozen_string_literal: true

require_relative "hibob_api_client"

class HibobIntegration
  Result = Struct.new(:success, :value)

  CV_DOCUMENT_TAG = "CV".freeze

  def initialize(auth_token)
    @auth_token = auth_token
  end

  def handle_application_hired(application)
    application_attributes = application_attributes(application)
    hibob_employee = find_or_create_employee(application_attributes)
    employee_id = hibob_employee.fetch("id")

    upload_cv(application_attributes, employee_id)

    Result.new(true, "Employee created in HiBob with ID #{employee_id}")
  end

  private

  def hibob_api_client
    @hibob_api_client ||= HibobApiClient.new(@auth_token)
  end

  def find_or_create_employee(application_attributes)
    email = application_attributes.fetch("email")

    hibob_api_client.get_employee(email) ||
      create_new_employee(
        application_attributes.fetch("first_name"),
        application_attributes.fetch("last_name"),
        email
      )
  end

  def create_new_employee(first_name, last_name, email)
    params = {
      "work" => {
        "site" => "New York (Demo)",
        "startDate" => "2024-05-30"
      },
      "firstName" => first_name,
      "surname" => last_name,
      "email" => email,
    }

    hibob_api_client.create_employee(params)
  end

  def upload_cv(application_attributes, employee_id)
    cv = application_attributes.fetch("attachments").find do |attachment|
      attachment.fetch("context") == "cv"
    end

    return if cv.empty? || cv_already_uploaded?(employee_id)

    params = {
      "documentName" => "#{application_attributes.fetch("first_name")} #{application_attributes.fetch("last_name")}'s CV",
      "documentUrl" => cv.fetch("url"),
      "tags" => [CV_DOCUMENT_TAG]
    }

    hibob_api_client.create_shared_document_for_employee(employee_id, params)
  end

  def cv_already_uploaded?(employee_id)
    hibob_api_client.get_shared_documents_for_employee_by_tag(employee_id, CV_DOCUMENT_TAG).any?
  end

  def application_attributes(application)
    application.dig("data", "attributes")
  end
end
