class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps,
  # form validation, and CSS nesting.
  allow_browser versions: :modern

  # A write Rails refuses never reaches an action, so it renders an error page
  # with no turbo-frame in it — and Turbo, finding no frame to swap, tells the
  # user "Content missing" and nothing else. That is how a misconfiguration
  # becomes a form that silently does nothing.
  #
  # Say what happened, in the panel the user is looking at.
  rescue_from ActionController::InvalidAuthenticityToken do
    render template: "shared/rejected", layout: false, status: :unprocessable_entity
  end
end
