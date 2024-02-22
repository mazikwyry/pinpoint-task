describe "/application_webhooks", type: :request do
  describe "when webhook event type is `application_hired`" do
    context "when application exists in Pinpoint and employee has not been created yet" do
      it "creates HiBob employee with CV, creates comment under Pinpoint's application and returns 200" do
        application_id = 8863902
        first_name = "Brian"
        last_name = "Farrell"
        email = "brian.farrell@pinpoint.dev"
        attachment_url = "https://pinpointhq.com/tom_hacquoil.pdf"
        employee_id = "5f4e3d3e-4e3d-4e3d-4e3d-4e3d4e3d4e3d"
        document_name = "#{first_name} #{last_name}'s CV"
        comment = "Employee created in HiBob with ID #{employee_id}"

        stub_pinpoint_fetch_application(application_id, first_name, last_name, email, attachment_url)
        stub_hibob_fetch_employee(email)
        stub_hibob_create_employee(employee_id, first_name, last_name, email)
        stub_hibob_fetch_documents(employee_id)
        stub_hibob_create_document(employee_id, attachment_url, document_name)
        stub_pinpoint_create_comment(application_id, comment)

        params = webhook_payload(application_id)

        post('/application_webhooks', body: params.to_json, headers: { 'Content-Type' => 'application/json' })

        expect(a_request(:post, "https://api.hibob.com/v1/people")).to have_been_made.once
        expect(a_request(:post, "https://api.hibob.com/v1/docs/people/#{employee_id}/shared")).to have_been_made.once
        expect(a_request(:post, "https://developers-test.pinpointhq.com/api/v1/comments")).to have_been_made.once
        expect(response.status).to eq 200
      end
    end

    context "when application exists in Pinpoint and employee has already been created with CV" do
      it "doesn't create new employee nor CV document, creates comment and returns 200" do
        application_id = 8863902
        first_name = "Brian"
        last_name = "Farrell"
        email = "brian.farrell@pinpoint.dev"
        attachment_url = "https://pinpointhq.com/tom_hacquoil.pdf"
        employee_id = "5f4e3d3e-4e3d-4e3d-4e3d-4e3d4e3d4e3d"
        comment = "Employee created in HiBob with ID #{employee_id}"

        stub_pinpoint_fetch_application(application_id, first_name, last_name, email, attachment_url)
        stub_hibob_fetch_employee(email, employee_id) # returns already existing employee

        documents = [{
          doc: {
            id: "123123",
            name: "#{first_name} #{last_name}'s CV",
            tags: ["CV"],
          }
        }]

        stub_hibob_fetch_documents(employee_id, documents) # returns already created CV document
        stub_pinpoint_create_comment(application_id, comment)

        params = webhook_payload(application_id)

        post('/application_webhooks', body: params.to_json, headers: { 'Content-Type' => 'application/json' })

        expect(a_request(:post, "https://api.hibob.com/v1/people")).to_not have_been_made
        expect(a_request(:post, "https://api.hibob.com/v1/docs/people/#{employee_id}/shared")).to_not have_been_made
        expect(response.status).to eq 200
      end
    end

    context "when application exists in Pinpoint and employee has already been created *without* CV" do
      it "creates CV document for existing employee, creates comment and returns 200" do
        application_id = 8863902
        first_name = "Brian"
        last_name = "Farrell"
        email = "brian.farrell@pinpoint.dev"
        attachment_url = "https://pinpointhq.com/tom_hacquoil.pdf"
        employee_id = "5f4e3d3e-4e3d-4e3d-4e3d-4e3d4e3d4e3d"
        comment = "Employee created in HiBob with ID #{employee_id}"
        document_name = "#{first_name} #{last_name}'s CV"

        stub_pinpoint_fetch_application(application_id, first_name, last_name, email, attachment_url)
        stub_hibob_fetch_employee(email, employee_id) # returns already existing employee
        stub_hibob_fetch_documents(employee_id)
        stub_hibob_create_document(employee_id, attachment_url, document_name)
        stub_pinpoint_create_comment(application_id, comment)

        params = webhook_payload(application_id)

        post('/application_webhooks', body: params.to_json, headers: { 'Content-Type' => 'application/json' })

        expect(a_request(:post, "https://api.hibob.com/v1/people")).to_not have_been_made
        expect(response.status).to eq 200
      end
    end

    context "when application doesn't exist in Pinpoint" do
      it "returns 404" do
        application_id = 8863902

        stub_pinpoint_fetch_application_404(application_id)

        params = webhook_payload(application_id)

        post('/application_webhooks', body: params.to_json, headers: { 'Content-Type' => 'application/json' })

        expect(response.status).to eq(404)
      end
    end

    context "when application_id is not present in the webhook payload" do
      it "returns 400" do
        params = webhook_payload(nil)

        post('/application_webhooks', body: params.to_json, headers: { 'Content-Type' => 'application/json' })

        expect(response.status).to eq(400)
      end
    end

    context "when event type is not supported" do
      it "returns 422" do
        params = webhook_payload(123, event: "application_rejected")

        post('/application_webhooks', body: params.to_json, headers: { 'Content-Type' => 'application/json' })

        expect(response.status).to eq(422)
      end
    end

    context "when creating employee via HiBob API fails with 4xx" do
      it "returns 500" do
        application_id = 8863902
        first_name = "Brian"
        last_name = "Farrell"
        email = "brian.farrell@pinpoint.dev"
        attachment_url = "https://pinpointhq.com/tom_hacquoil.pdf"

        stub_pinpoint_fetch_application(application_id, first_name, last_name, email, attachment_url)
        stub_hibob_fetch_employee(email)
        stub_hibob_create_employee(nil, first_name, last_name, email, status: 400)

        params = webhook_payload(application_id)

        post('/application_webhooks', body: params.to_json, headers: { 'Content-Type' => 'application/json' })

        expect(response.status).to eq(500)
      end
    end

    context "when creating employee via HiBob API fails with 5xx" do
      it "returns 500" do
        application_id = 8863902
        first_name = "Brian"
        last_name = "Farrell"
        email = "brian.farrell@pinpoint.dev"
        attachment_url = "https://pinpointhq.com/tom_hacquoil.pdf"

        stub_pinpoint_fetch_application(application_id, first_name, last_name, email, attachment_url)
        stub_hibob_fetch_employee(email)
        stub_hibob_create_employee(nil, first_name, last_name, email, status: 500)

        params = webhook_payload(application_id)

        post('/application_webhooks', body: params.to_json, headers: { 'Content-Type' => 'application/json' })

        expect(response.status).to eq(500)
      end
    end

    context "when creating comment via Pinpoint API fails with 4xx" do
      it "returns 500" do
        application_id = 8863902
        first_name = "Brian"
        last_name = "Farrell"
        email = "brian.farrell@pinpoint.dev"
        attachment_url = "https://pinpointhq.com/tom_hacquoil.pdf"
        employee_id = "5f4e3d3e-4e3d-4e3d-4e3d-4e3d4e3d4e3d"
        document_name = "#{first_name} #{last_name}'s CV"
        comment = "Employee created in HiBob with ID #{employee_id}"

        stub_pinpoint_fetch_application(application_id, first_name, last_name, email, attachment_url)
        stub_hibob_fetch_employee(email)
        stub_hibob_create_employee(employee_id, first_name, last_name, email)
        stub_hibob_fetch_documents(employee_id)
        stub_hibob_create_document(employee_id, attachment_url, document_name)
        stub_pinpoint_create_comment(application_id, comment, status: 422)

        params = webhook_payload(application_id)

        post('/application_webhooks', body: params.to_json, headers: { 'Content-Type' => 'application/json' })

        expect(response.status).to eq(500)
      end
    end

    context "when creating comment via Pinpoint API fails with 5xx" do
      it "returns 500" do
        application_id = 8863902
        first_name = "Brian"
        last_name = "Farrell"
        email = "brian.farrell@pinpoint.dev"
        attachment_url = "https://pinpointhq.com/tom_hacquoil.pdf"
        employee_id = "5f4e3d3e-4e3d-4e3d-4e3d-4e3d4e3d4e3d"
        document_name = "#{first_name} #{last_name}'s CV"
        comment = "Employee created in HiBob with ID #{employee_id}"

        stub_pinpoint_fetch_application(application_id, first_name, last_name, email, attachment_url)
        stub_hibob_fetch_employee(email)
        stub_hibob_create_employee(employee_id, first_name, last_name, email)
        stub_hibob_fetch_documents(employee_id)
        stub_hibob_create_document(employee_id, attachment_url, document_name)
        stub_pinpoint_create_comment(application_id, comment, status: 522)

        params = webhook_payload(application_id)

        post('/application_webhooks', body: params.to_json, headers: { 'Content-Type' => 'application/json' })

        expect(response.status).to eq(500)
      end
    end
  end

  def webhook_payload(application_id, event: "application_hired")
    {
      "event" => event,
      "triggeredAt" => 1614687278,
      "data" => {
        "application" => {
          "id" => application_id
        },
        "job" => {
          "id" => 1
        }
      }
    }
  end

  def stub_pinpoint_fetch_application(application_id, first_name, last_name, email, attachment_url)
    fetch_application_response = {
      "data": {
        "id": application_id.to_s,
        "type": "applications",
        "attributes": {
          "first_name": first_name,
          "last_name": last_name,
          "email": email,
          "attachments": [
            {
              "context": "cv",
              "filename": "tom_hacquoil.pdf",
              "url": attachment_url,
            },
            {
              "context": "pdf_cv",
              "filename": "tom_hacquoil.pdf",
              "url": attachment_url,
            }
          ]
        },
      }
    }

    stub_request(:get, "https://developers-test.pinpointhq.com/api/v1/applications/#{application_id}?extra_fields[applications]=attachments").
      to_return(body: fetch_application_response.to_json, status: 200)
  end

  def stub_pinpoint_fetch_application_404(application_id)
    stub_request(:get, "https://developers-test.pinpointhq.com/api/v1/applications/#{application_id}?extra_fields[applications]=attachments").
      to_return(body: "{}", status: 404)
  end

  def stub_hibob_fetch_employee(email, employee_id = nil)
    fetch_employee_params = {
      "filters" => [{
        "fieldPath" => "root.email",
        "operator" => "equals",
        "values" => [email]
      }],
      "showInactive" => true
    }

    create_employee_response = { employees: employee_id ? [{ "id": employee_id }] : [] }

    stub_request(:post, "https://api.hibob.com/v1/people/search").
      with(body: fetch_employee_params.to_json).
      to_return(status: 200, body: create_employee_response.to_json)
  end

  def stub_hibob_create_employee(employee_id, first_name, last_name, email, status: 200)
    create_employee_params = {
      "work" => {
        "site" => "New York (Demo)",
        "startDate" => "2024-05-30"
      },
      "firstName" => first_name,
      "surname" => last_name,
      "email" => email,
    }

    create_employee_response = status == 200 ? { id: employee_id } : {}

    stub_request(:post, "https://api.hibob.com/v1/people").
      with(body: create_employee_params.to_json).
      to_return(status:, body: create_employee_response.to_json)
  end

  def stub_hibob_fetch_documents(employee_id, documents = [])
    fetch_documents_response = { documents: }

    stub_request(:get, "https://api.hibob.com/v1/docs/people/#{employee_id}").
      to_return(status: 200, body: fetch_documents_response.to_json)
  end

  def stub_hibob_create_document(employee_id, document_url, document_name)
    create_document_params = {
      "documentName" => document_name,
      "documentUrl" => document_url,
      "tags" => ["CV"]
    }

    stub_request(:post, "https://api.hibob.com/v1/docs/people/#{employee_id}/shared").
      with(body: create_document_params.to_json).
      to_return(status: 200, body: "{}")
  end

  def stub_pinpoint_create_comment(application_id, comment, status: 201)
    create_comment_params = {
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

    stub_request(:post, "https://developers-test.pinpointhq.com/api/v1/comments").
      with(body: create_comment_params.to_json).
      to_return(status:, body: "{}")
  end
end
