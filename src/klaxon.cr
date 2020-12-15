require "http/client"
require "schedule"

require "./check"
require "./checklist"
require "./log"

include Klaxon::Log

[
  Signal::INT,
  Signal::TERM
].each do |signal|
  signal.trap do
    info "shutting down.."
    exit
  end
end

class Klaxon

  def self.verify_connection
    client = HTTP::Client.new(
      host: Klaxon.config.elasticsearch.host,
      port: Klaxon.config.elasticsearch.port,
      tls: Klaxon.config.elasticsearch.tls
    )
    unless Klaxon.config.elasticsearch.username.to_s.empty?
      client.basic_auth(
        Klaxon.config.elasticsearch.username,
        Klaxon.config.elasticsearch.password
      )
    end
    response = client.get(
      "/",
      headers: HTTP::Headers{"Content-Type" => "application/json"},
    )

    response_json = JSON.parse(response.body)
    if response_json.as_h.keys.includes?("cluster_uuid")
      info "connected to #{Klaxon.config.elasticsearch.host}"
    else
      raise "general failure, check auth credentials"
    end
  rescue ex
    error "#{ex.class}: #{ex}"
    error "unable to connect to #{Klaxon.config.elasticsearch.host}"
    exit 1
  end

  def self.start
    info "📣 starting up"
    verify_connection
    list = Klaxon::Checks.new.list
    checks = list.map{|c| Klaxon::Check.new(item: c)}
    checks.each do |c|
      Schedule::Runner.new.every(c.interval) do
        elapsed_time = Time.measure do
          c.execute
        end
        info "{#{c.name.colorize(:light_blue)}} took #{elapsed_time.total_milliseconds.round(1)}ms"
      end
    end
    loop do
      sleep 30
      info "processing notifications"
      Klaxon::Notifications.process_notifications
    end
  end
end

Klaxon.start

# Tasker
# require "tasker"
# CHECKS.each do |i|
#   Tasker.every(15.seconds) {
#     elapsed_time = Time.measure do
#       Klaxon::Check.new(item: i).execute
#     end
#     puts "{#{i.name}} took #{elapsed_time.total_milliseconds.round(1)}ms"
#   }
# end
# loop do
#   sleep 10
# end

# Mosquito
# require "mosquito"
# Mosquito::Redis.instance.flushall
# macro load_jobs
#   {% count = 2 %}
#   {% for i in (0..count-1) %}
#     class Check_{{i}} < Mosquito::PeriodicJob
#       run_every 5.seconds

#       def perform
#         if CHECKS[{{i}}]?
#           sleep 5
#           Klaxon::Check.new(CHECKS[{{i}}]).execute
#         else
#           fail
#         end
#       end
#     end
#   {% end %}
# end
# load_jobs
# Mosquito.configure do |settings|
#   settings.redis_url = "redis://#{Klaxon::CONFIG.redis.host}:#{Klaxon::CONFIG.redis.port}"
# end
# Mosquito::Runner.start
