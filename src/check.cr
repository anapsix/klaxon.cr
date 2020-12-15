require "http/client"

require "./checklist"
require "./config"
require "./log"
require "./notifications/notifications"
require "./query"

class Klaxon
  class Check

    include Klaxon::Log
    include Klaxon::Query::Aliases

    @item : Klaxon::Checks::List::Item
    @config : Klaxon::Config

    @name : String

    @client : HTTP::Client
    @query : Klaxon::Query

    def initialize(
      @item,
      @config = Klaxon::CONFIG)

      @name = @item.name

      client = HTTP::Client.new(
        host: @config.elasticsearch.host,
        port: @config.elasticsearch.port,
        tls: @config.elasticsearch.tls
      )
      unless @config.elasticsearch.username.to_s.empty?
        client.basic_auth(
          @config.elasticsearch.username,
          @config.elasticsearch.password
        )
      end

      @client = client
      @query = Klaxon::Query.new(query: @item.query)

      if @item.notification.enabled && @item.notification.recipient
        Klaxon::Notifications.register(@item)
      end
    end

    def query
      @query
    end

    def name
      @name
    end

    def interval
      @item.interval
    end

    private def triggered?(value) : Bool
      return true if value == Float64::INFINITY
      return true if value.nil?
      case @item.trigger.operator
      when "gte", ">="
        value >= @item.trigger.threshold
      when "gt", ">"
        value > @item.trigger.threshold
      when "eq", "=="
        value == @item.trigger.threshold
      when "ne", "!="
        value != @item.trigger.threshold
      when "lte", "<="
        value <= @item.trigger.threshold
      when "lt", "<"
        value < @item.trigger.threshold
      else
        raise "'#{@item.trigger.operator}' operator is not supported"
      end
    end

    private def update_notifications(check_result : Bool, check_value) : Nil
      if @item.notification.enabled
        Klaxon::Notifications.update_check_status(@item.name, check_result, check_value.to_s)
      end
    end

    def execute
      response = @client.get(
        "/#{@item.query.index}/_search",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
        body: @query.to_s
      )

      response_json = JSON.parse(response.body)
      aggregations = response_json["aggregations"]

      case @item.query.aggs.type
      when "avg"
        check_value = aggregations["metric"]["value"]
        check_value = check_value.as_i? || check_value.as_i64? || check_value.as_f32? || check_value.as_f? || 0
        check_value = check_value.round(3)
      when "percent"
        numerator = aggregations["all"]["buckets"]["numerator"]["doc_count"]
        numerator = numerator.as_i? || numerator.as_i64? || 1
        denominator = aggregations["all"]["buckets"]["denominator"]["doc_count"]
        denominator = denominator.as_i? || denominator.as_i64? || 0
        check_value = (numerator / denominator).to_f32.round(3)
      end

      info "{#{@name.colorize(:light_blue)}} #{@item.query.aggs.type}: #{check_value}"

      check_result = false
      if self.triggered?(check_value)
        comp_res = "FAILED".colorize(:red)
      else
        check_result = true
        comp_res = "OK".colorize(:green)
      end

      info "{#{@name.colorize(:light_blue)}} trigger condition: #{check_value} #{@item.trigger.operator} #{@item.trigger.threshold}"
      notice "{#{@name.colorize(:light_blue)}} result: #{comp_res}"

      update_notifications(check_result, check_value)
      check_result
    end
  end
end

# list = Klaxon::Checks.new.list
# checks = list.map{|c| Klaxon::Check.new(item: c)}
# checks.each do |c|
#   c.execute
# end

# # pp Klaxon::Notifications.check_recipients
# pp Klaxon::Notifications.check_status
# pp Klaxon::Notifications.check_thesholds
