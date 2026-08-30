Rails.application.routes.draw do
  # There is no authentication here, and that is deliberate rather than unfinished.
  # Uplink binds to 127.0.0.1, stores nothing but the shape of your own LAN, and
  # every service it shows is a hyperlink you could have typed yourself. A login
  # screen would protect a machine you are already sitting at from a person who
  # is already you. CSRF protection stays on for everything that writes, because
  # that guards against a website you visit, not against you.

  root "uplink#show"

  resources :nodes, except: %i[ index show ] do
    resources :services, only: %i[ new create ], shallow: true
  end
  resources :services, only: %i[ edit update destroy ]
  resources :links, only: %i[ create destroy ]
  resources :speedtests, only: %i[ create ]

  # The desktop talking to the app. /theme.css is what the browser fetches;
  # /theme/changed is what the omarchy theme-set hook pokes.
  get  "theme.css"       => "theme#stylesheet", as: :theme_stylesheet, format: false
  get  "theme/wallpaper" => "theme#wallpaper"
  post "theme/changed"   => "theme#changed"

  get "up" => "rails/health#show", as: :rails_health_check
end
