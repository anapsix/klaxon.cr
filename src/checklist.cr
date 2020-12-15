require "yaml"

require "./interval_converter"
require "./notifications/notifications"
require "./log"

class Klaxon
  struct Checks
    include Klaxon::Log

    struct List
      include YAML::Serializable

      struct Item
        include YAML::Serializable

        struct Query
          include YAML::Serializable

          struct Aggs
            include YAML::Serializable
            getter type : String
            getter numerator : String?
            getter denominator : String?
            getter field : String?
          end

          # struct AggsAvg
          #   include YAML::Serializable
          #   getter type : String

          # end

          getter index : String
          getter string : String
          getter range : NamedTuple(gte: String, lte: String) = { gte: "now-10m/m", lte: "now/m" }
          getter aggs : Aggs
        end

        struct Trigger
          include YAML::Serializable
          getter operator : String
          getter threshold : Int32 | Int64 | Float32
        end

        struct Notification
          include YAML::Serializable
          getter enabled : Bool = false
          getter type : String? = nil
          getter recipient : String? = nil
          getter failure_threshold : UInt8 = Klaxon::Notifications::FAILURE_THRESHOLD

          def initialize
          end
        end

        getter name : String
        @[YAML::Field(converter: Klaxon::IntervalConverter)]
        getter interval : Time::Span
        getter query : Query
        getter trigger : Trigger
        getter notification : Notification = Klaxon::Checks::List::Item::Notification.new
      end

      @[YAML::Field(key: "checklist")]
      getter list : Array(Item)
    end

    @file : String
    getter list : Array(List::Item)

    def initialize(file : String | Nil = nil)
      file ||= ENV.fetch("KLAXON_COLLECTION", "./collection.yaml")
      @file = file
      if File.readable?(file)
        info "loading checks from #{@file} .."
        @list = List.from_yaml(File.read(@file)).list
        @list.each do |check|
          info "{#{check.name.colorize(:light_blue)}} found"
        end
        info "finished loading checks"
      else
        error "#{file} is not readable"
        exit 1
      end
    end
  end
end

# a = Klaxon::Checks.new
# a.list.each do |c|
#   puts
#   puts c.class
#   puts c.name
#   puts c.interval
#   puts "Notifications enabled #{c.notification.enabled}"
#   puts "Failure Threshold: #{c.notification.failure_threshold}"
# end
