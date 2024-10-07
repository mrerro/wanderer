import Config
import WandererApp.ConfigHelpers

if System.get_env("PHX_SERVER") do
  config :wanderer_app, WandererAppWeb.Endpoint, server: true
end

config_dir = System.get_env("CONFIG_DIR", "/run/secrets")

app_name = System.get_env("FLY_APP_NAME", "NOT_FLY_APP")

host =
  case app_name == "NOT_FLY_APP" do
    true -> System.get_env("PHX_HOST", "localhost")
    _ -> "#{app_name}.fly.dev"
  end

web_port =
  System.get_env(
    "PORT",
    case config_env() do
      :test -> "5000"
      _env -> "8000"
    end
  )
  |> String.to_integer()

web_app_url =
  case app_name == "NOT_FLY_APP" do
    true -> System.get_env("WEB_APP_URL", "http://#{host}:#{web_port}")
    _ -> "https://#{host}"
  end

base_url = URI.parse(web_app_url)

if base_url.scheme not in ["http", "https"] do
  raise "WEB_APP_URL must start with `http` or `https`. Currently configured as `#{System.get_env("WEB_APP_URL")}`"
end

http_port = System.get_env("HTTP_PORT", "80") |> String.to_integer()
https_port = System.get_env("HTTPS_PORT", "443") |> String.to_integer()

port =
  case app_name == "NOT_FLY_APP" do
    true -> System.get_env("WEB_EXTERNAL_PORT", "#{web_port}") |> String.to_integer()
    _ -> http_port
  end

scheme = System.get_env("WEB_EXTERNAL_SCHEME", "http")

map_subscriptions_enabled =
  config_dir
  |> get_var_from_path_or_env("WANDERER_MAP_SUBSCRIPTIONS_ENABLED", "false")
  |> String.to_existing_atom()

map_subscription_characters_limit =
  config_dir
  |> get_int_from_path_or_env("WANDERER_MAP_SUBSCRIPTION_CHARACTERS_LIMIT", 100)

map_subscription_hubs_limit =
  config_dir
  |> get_int_from_path_or_env("WANDERER_MAP_SUBSCRIPTION_HUBS_LIMIT", 10)

wallet_tracking_enabled =
  config_dir
  |> get_var_from_path_or_env("WANDERER_WALLET_TRACKING_ENABLED", "false")
  |> String.to_existing_atom()

admins =
  System.get_env("WANDERER_ADMINS", "")
  |> case do
    "" -> []
    admins -> admins |> String.split(",")
  end

config :wanderer_app,
  web_app_url: web_app_url,
  git_sha: System.get_env("GIT_SHA", "111"),
  custom_route_base_url: System.get_env("CUSTOM_ROUTE_BASE_URL"),
  invites: System.get_env("WANDERER_INVITES", "false") == "true",
  admin_username: System.get_env("WANDERER_ADMIN_USERNAME", "admin"),
  admin_password: System.get_env("WANDERER_ADMIN_PASSWORD"),
  admins: admins,
  corp_id: System.get_env("WANDERER_CORP_ID", "-1") |> String.to_integer(),
  corp_wallet: System.get_env("WANDERER_CORP_WALLET", ""),
  map_subscriptions_enabled: map_subscriptions_enabled,
  wallet_tracking_enabled: wallet_tracking_enabled,
  subscription_settings: %{
    plans: [
      %{
        id: "alpha",
        characters_limit: map_subscription_characters_limit,
        hubs_limit: map_subscription_hubs_limit,
        base_price: 0,
        monthly_discount: 0
      },
      %{
        id: "omega",
        characters_limit: 300,
        hubs_limit: 20,
        base_price: 250_000_000,
        month_3_discount: 0.2,
        month_6_discount: 0.4,
        month_12_discount: 0.5
      }
    ],
    extra_characters_100: 75_000_000,
    extra_hubs_10: 25_000_000
  }

config :ueberauth, Ueberauth,
  providers: [
    eve:
      {WandererApp.Ueberauth.Strategy.Eve,
       [
         default_scope:
           "esi-location.read_location.v1 esi-location.read_ship_type.v1 esi-location.read_online.v1 esi-ui.write_waypoint.v1 esi-search.search_structures.v1",
         wallet_scope:
           "esi-location.read_location.v1 esi-location.read_ship_type.v1 esi-location.read_online.v1 esi-ui.write_waypoint.v1 esi-search.search_structures.v1 esi-wallet.read_character_wallet.v1",
         admin_scope:
           "esi-location.read_location.v1 esi-location.read_ship_type.v1 esi-location.read_online.v1 esi-ui.write_waypoint.v1 esi-search.search_structures.v1 esi-wallet.read_character_wallet.v1 esi-wallet.read_corporation_wallets.v1 esi-mail.send_mail.v1",
         callback_url: "#{web_app_url}/auth/eve/callback"
       ]}
  ]

config :ueberauth, WandererApp.Ueberauth.Strategy.Eve.OAuth,
  client_id: {WandererApp.Ueberauth, :client_id},
  client_secret: {WandererApp.Ueberauth, :client_secret},
  client_id_default: System.get_env("EVE_CLIENT_ID", "<EVE_CLIENT_ID>"),
  client_id_with_wallet:
    System.get_env("EVE_CLIENT_WITH_WALLET_ID", "<EVE_CLIENT_WITH_WALLET_ID>"),
  client_id_with_corp_wallet:
    System.get_env("EVE_CLIENT_WITH_CORP_WALLET_ID", "<EVE_CLIENT_WITH_CORP_WALLET_ID>"),
  client_secret_default: System.get_env("EVE_CLIENT_SECRET", "<EVE_CLIENT_SECRET>"),
  client_secret_with_wallet:
    System.get_env("EVE_CLIENT_WITH_WALLET_SECRET", "<EVE_CLIENT_WITH_WALLET_SECRET>"),
  client_secret_with_corp_wallet:
    System.get_env("EVE_CLIENT_WITH_CORP_WALLET_SECRET", "<EVE_CLIENT_WITH_CORP_WALLET_SECRET>")

config :logger,
  level:
    String.to_existing_atom(
      System.get_env(
        "LOG_LEVEL",
        case config_env() do
          :prod -> "info"
          :dev -> "info"
          :test -> "debug"
        end
      )
    )

sheduler_jobs =
  map_subscriptions_enabled
  |> case do
    true ->
      [
        {"@hourly", {WandererApp.Map.SubscriptionManager, :process, []}}
      ]

    _ ->
      []
  end

config :wanderer_app, WandererApp.Scheduler,
  timezone: :utc,
  jobs:
    [
      {"@daily", {WandererApp.Map.Audit, :archive, []}}
    ] ++ sheduler_jobs,
  timeout: :infinity

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 =
    config_dir
    |> get_var_from_path_or_env("ECTO_IPV6", "false")
    |> String.to_existing_atom()
    |> case do
      true -> [:inet6]
      _ -> []
    end

  db_ssl_enabled =
    config_dir
    |> get_var_from_path_or_env("DATABASE_SSL_ENABLED", "false")
    |> String.to_existing_atom()

  db_ssl_verify_none =
    config_dir
    |> get_var_from_path_or_env("DATABASE_SSL_VERIFY_NONE", "false")
    |> String.to_existing_atom()

  client_opts =
    if db_ssl_verify_none do
      [verify: :verify_none]
    end

  config :wanderer_app, WandererApp.Repo,
    url: database_url,
    ssl: db_ssl_enabled,
    ssl_opts: client_opts,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :wanderer_app, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :wanderer_app, WandererAppWeb.Endpoint,
    url: [scheme: base_url.scheme, host: base_url.host, path: base_url.path, port: base_url.port],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0},
      port: web_port
    ],
    secret_key_base: secret_key_base

  if scheme == "https" && http_port do
    config :wanderer_app, WandererAppWeb.Endpoint,
      url: [host: host, port: 443, scheme: scheme],
      server: true,
      force_ssl: [hsts: true],
      http: [
        port: http_port
      ],
      https: [
        port: https_port,
        cipher_suite: :strong,
        otp_app: :wanderer_app,
        keyfile: "/certs/private.key",
        certfile: "/certs/certificate.crt"
      ]

    config :wanderer_app, WandererApp.PromEx,
      grafana: [
        host: System.get_env("GRAFANA_CLOUD_HOST", "<GRAFANA_CLOUD_HOST>"),
        auth_token: System.get_env("GRAFANA_CLOUD_AUTH_TOKEN", "<GRAFANA_CLOUD_AUTH_TOKEN>"),
        folder_name: System.get_env("GRAFANA_CLOUD_FOLDER_NAME", "wanderer"),
        upload_dashboards_on_start: true
      ]

    config :wanderer_app,
      grafana_datasource_id: System.get_env("GRAFANA_DATASOURCE_ID", "wanderer")
  end

  promex_disabled? =
    config_dir
    |> get_var_from_path_or_env("PROMEX_DISABLED", "true")
    |> String.to_existing_atom()

  config :wanderer_app, WandererApp.PromEx,
    disabled: promex_disabled?,
    manual_metrics_start_delay: :no_delay,
    metrics_server: [
      port: System.get_env("METRICS_PORT", "4021") |> String.to_integer(),
      path: "/metrics",
      protocol: :http,
      pool_size: 5,
      cowboy_opts: [ip: {0, 0, 0, 0}]
    ]
end
