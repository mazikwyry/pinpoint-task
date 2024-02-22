# frozen_string_literal: true

class PinpointApiClient
  Error = Class.new(StandardError)

  def initialize(api_key, subdomain)
    @api_key = api_key
    @subdomain = subdomain
  end

  def get_application(application_id)
    path = "applications/#{application_id}?extra_fields[applications]=attachments"
    response = get(path)

    if response.code == "200"
      JSON.parse(response.read_body)
    elsif response.code == "404"
      nil
    else
      raise(Error, "Fetching application failed: #{response.code} #{response.read_body}")
    end
  rescue JSON::ParserError
    raise(Error, "Fetching application failed: Invalid JSON response")
  end

  def create_comment_for_application(application_id, comment)
    url = "comments"

    params = {
      "data" => {
        "attributes" => {
          "body_text" => comment
        },
        "relationships" => {
          "commentable" =>
            {
              "data" => {
                "type" => "applications",
                "id" => application_id
              }
            }
        },
        "type" => "comments"
      }
    }

    response = post(url, params)

    if response.code != "201"
      raise(Error, "Creating comment failed: #{response.code} #{response.read_body}")
    end
  end

  private

  def get(path)
    url = base_url + path
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Get.new(url)
    request["accept"] = 'application/vnd.api+json'
    request["X-API-KEY"] = @api_key

    http.request(request)
  end

  def post(path, params)
    url = base_url + path
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)
    request["accept"] = 'application/vnd.api+json'
    request["content-type"] = 'application/vnd.api+json'
    request["X-API-KEY"] = @api_key
    request.body = params.to_json

    http.request(request)
  end

  def base_url
    URI("https://#{@subdomain}.pinpointhq.com/api/v1/")
  end
end
