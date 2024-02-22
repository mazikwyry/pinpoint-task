# Pinpoint Webhooks

Hi there! 👋

This is my solution for the **Integration Engineer Assessment**.

## Solution considerations

### Language

First decision was which language to use. I was between JavaScript/Typescript and Ruby.
For this solo assessment, I decided to go with **Ruby**, as it is a language I love and I can deliver
a solution faster. I was also curious to see the ecosystem for lambdas in Ruby since my last attempt.
However for the production world I would really seriously consider using JavaScript/Typescript
because in the future it will be easier to find developers to maintain the code.

### Framework

Developing this function in the AWS console would be a pain (and in real world maintain it there would be a nightmare),
so I wanted to use a framework to help me with development, deployment and testing.
I found that the most popular one is Jets. I checked the documentation and it seemed to be a good fit for this project.
It's easy to setup and start coding, has everything you need to develop, test and deploy lambdas.

Big benefit is that you have a local server to test your lambdas, so you don't need to deploy to AWS to test your code.

The biggest downside is that the deployment process doesn't work for some unknown reason.
I reported the issue to the authors [here](https://community.boltops.com/t/cant-deploy-basic-api/1160).
(I found a workaround to deploy the lambda, but it's not ideal)

More about that choice in further sections.

## Solution design

The solution implements the task requirements and includes some ideas on how it could look like in the real world.

### The idea

The idea is to have one controller/function (I'll call it _webhook handler_) per Pinpoint resource which handles
different events related to that resource.
The _webhook handler_:

- Validates the webhook
- Dispatches the webhook
- Recognizes the current tenant (from the webhook payload/headers)
- Fetches the related resource from the Pinpoint API (or separate DB)
- Fetches enabled integrations (with credentials) for the current tenant from the Pinpoint API (or separate DB)
- Runs handlers for each enabled integration

This design allows us to easily add new integrations plus we can have multiple
integrations for one webhook.

Possible downside might be that this is a resource-centric approach and might not fit all use cases.

Alternative approach is integration-centric, where we would have one controller/function per integration.
I don't know Pinpoint well enough to say which one would be better.

### The implementation

I implemented the _webhook handler_ as a lambda function using the Jets framework.

Here are the building blocks:

- `ApplicationWebhooksController` - the _webhook handler_ controller which dispatches the webhook, fetches the
  application and runs the handlers for each enabled integration
- `HibobIntegration` - encapsulates the logic for the hibob integration, we have just `handle_application_hired` method
  for now
    - `handle_application_hired` flow is as follows:
    - Check if there is already a employee with the same email (email is unique in Hibob)
    - If not, create a new employee
    - Check if the employee (new or exiting) have CV uploaded already
    - If not, upload the CV
- `PinpointApiClinet` and `HibobApiClient` - clients for the Pinpoint and Hibob APIs

The handler is idempotent, so subsequent requests for the same event will not create duplicate records in Hibob.
It also won't crash if the employee already exists in Hibob (this is important because that would cause the webhook to
retry and eventually after max retries exceeded to be disabled).

It might happen that in the first execution the employee is created but the CV is not uploaded.
In the second execution the integration will attempt to upload the CV again.

### Missing parts / shame list

#### Major

- **Whole execution is synchronous** - this is not ideal for a real world scenario becasue webhooks has timeouts (5s).
  If I had more time I would move execution(s) of integration handlers to separate lambdas.
- Webhook validation is not implemented - this is because I don't have access to the Pinpoint UI to get the secret key (
  also it would harder for testing)

#### Minor

- I focused on integration specs and didn't get to unit specs for `PinpointApiClinet` and `HibobApiClient`
- Deployment process is not working - I had to use a workaround to deploy the lambda
- No automatic e2e tests
- No Rubocop :(

## How to run

### Production

```shell
curl -v --location 'https://4bpk72vax7wkraaqqy7unhtwpi0ytrzn.lambda-url.us-east-1.on.aws/' \
--header 'Content-Type: application/json' \
--data '{
  "event": "application_hired",
  "triggeredAt": 1614687278,
  "data": {
    "application": {
      "id": 8925636
    },
    "job": {
      "id": 1
    }
  }
}
'
```

### Local

`bundle exec jets server`

### Tests

`bundle exec rspec`

## Conclusion

I had a lot of fun working on this project.
I learned a lot about the Pinpoint API, HiBob and the Jets framework.
I also learned that the Jets framework is not out-of-the-box production ready yet (at least the free version).
I would consider using it for a bigger project, but for a single lambda I would probably go with the Serverless
framework.

While working on this I already had some ideas on how to improve Pinpoint's API documentation and tooling.

I hope you like my solution and I'm looking forward to your feedback.
