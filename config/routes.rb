Jets.application.routes.draw do
  post "application_webhooks", to: "application_webhooks#handle"
end
