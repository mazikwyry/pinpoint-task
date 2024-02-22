# frozen_string_literal: true

class HibobApiClient
  Error = Class.new(StandardError)

  def initialize(auth_token)
    @auth_token = auth_token
  end

  def get_employee(email)
    params = {
      "filters" => [{
        "fieldPath" => "root.email",
        "operator" => "equals",
        "values" => [email]
      }],
      "showInactive" => true
    }

    response = post("people/search", params)

    if response.code == "200"
      with_json_response do
        JSON.parse(response.read_body).fetch("employees").first
      end
    else
      raise(Error, "Fetching employee failed: #{response.code} #{response.read_body}")
    end
  end

  def create_employee(params)
    response = post("people", params)

    if response.code == "200"
      with_json_response { JSON.parse(response.read_body) }
    else
      raise(Error, "Creating employee failed: #{response.code} #{response.read_body}")
    end
  end

  def get_shared_documents_for_employee_by_tag(employee_id, tag)
    response = get("docs/people/#{employee_id}")

    if response.code == "200"
      with_json_response do
        documents = JSON.parse(response.read_body).fetch("documents")
        documents.select { |document| document.dig("doc", "tags").include?(tag) }
      end
    else
      raise(Error, "Fetching shared documents failed: #{response.code} #{response.read_body}")
    end
  end

  def create_shared_document_for_employee(employee_id, params)
    response = post("docs/people/#{employee_id}/shared", params)

    if response.code == "200"
      with_json_response { JSON.parse(response.read_body) }
    else
      raise(Error, "Creating shared document failed: #{response.code} #{response.read_body}")
    end
  end

  private

  def post(path, params)
    url = base_url + path
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["accept"] = 'application/json'
    request["content-type"] = 'application/json'
    request["authorization"] = "Basic #{@auth_token}"
    request.body = params.to_json

    http.request(request)
  end

  def get(path)
    url = base_url + path
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)
    request["accept"] = 'application/json'
    request["authorization"] = "Basic #{@auth_token}"

    http.request(request)
  end

  private

  def with_json_response
    yield
  rescue JSON::ParserError
    raise(Error, "Invalid JSON response")
  end

  def base_url
    URI("https://api.hibob.com/v1/")
  end
end
