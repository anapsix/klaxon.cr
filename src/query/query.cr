require "json"

require "./aliases"
require "../checklist"

class Klaxon
  class Query

    include Klaxon::Query::Aliases

    private QUERY = {
      "aggs": QueryAggregations.new,
      "query": {
        "bool": {
          "filter": Array(QueryFilter).new
        }
      },
      "size": 0
    }

    @query : Klaxon::Checks::List::Item::Query

    @range_filter : QueryFilter
    @query_filter : QueryFilter
    @qq : QueryBuilder

    def initialize(@query)

      @range_filter = {
                        "range": {
                          "@timestamp": {
                            "gte": @query.range[:gte],
                            "lte": @query.range[:lte]
                          }
                        }
                      }
      @query_filter = {
                        "query_string": {
                          "analyze_wildcard": true,
                          "query": @query.string
                        }
                      }

      case @query.aggs.type
      when "avg"
        aggs = {
                  "metric": {
                    "avg": {
                      "field": @query.aggs.field
                    }
                  }
                }.to_h
      when "percent"
      aggs = {
                "all": {
                  "filters": {
                    "filters": {
                      "denominator": {
                        "query_string": {
                          "analyze_wildcard": true,
                          "query": @query.aggs.denominator
                        }
                      },
                      "numerator": {
                        "query_string": {
                          "analyze_wildcard": true,
                          "query": @query.aggs.numerator
                        }
                      }
                    }
                  }
                }
              }.to_h
      else
        raise "unexpected aggs type"
      end

      # aggs =  case @query.aggs.type
      #         when "avg"
      #           {
      #             "metric": {
      #               "avg": {
      #                 "field": "@query.aggs.field"
      #               }
      #             }
      #           }.to_h
      #         when "percent"
      #           {
      #             "all": {
      #               "filters": {
      #                 "filters": {
      #                   "denominator": {
      #                     "query_string": {
      #                       "analyze_wildcard": true,
      #                       "query": "@query.aggs.denominator"
      #                     }
      #                   },
      #                   "numerator": {
      #                     "query_string": {
      #                       "analyze_wildcard": true,
      #                       "query": "@query.aggs.numerator"
      #                     }
      #                   }
      #                 }
      #               }
      #             }
      #           }.to_h
      #         end

      q = QUERY.clone
      q[:aggs].merge!(aggs)
      q[:query][:bool][:filter] << @range_filter
      q[:query][:bool][:filter] << @query_filter
      @qq = q
      # self.validate_offset(@range[:gte])
      # self.validate_offset(@range[:lte])
    end

    def to_s : String
      # q[:query][:bool][:filter][:range]["@timestamp"]["gte"] = self.time(@range[:gte])
      # q[:query][:bool][:filter][:range]["@timestamp"]["lte"] = self.time(@range[:lte])
      @qq.to_json
    end

    # unused
    private def validate_offset(offset : String) : Nil
      validator = /^now( - \d+[mhd])?$/
      raise "'#{offset}' format is unsupported, must match #{validator.inspect}" unless offset.match(validator)
    end

    # unused
    private def time(offset : String = "now")
      self.validate_offset(offset)
      time = Time.utc.at_beginning_of_minute
      if offset == "now"
        timestamp = time
      else
        offset_a = offset.split(/\s+-\s+/)
        md = offset_a.last.match(/(\d+)(\w+)/)
        md_a = md ? md.to_a : Array(String).new
        raise "failed to parse offset '#{offset}'" if md_a.empty?
        amount = md_a[1]?
        measure = md_a[2]?
        raise "amount cannot be Nil" if amount.nil?
        raise "measure cannot be Nil" if measure.nil?
        amount = amount.to_u16
        timestamp = case measure
                    when "m"
                      time - amount.minutes
                    when "h"
                      time - amount.hours
                    when "d"
                      time - amount.days
                    else
                      raise "time measure '#{measure} of #{measure.class}' is unsupported"
                    end
      end
      timestamp.to_rfc3339(fraction_digits: 3)
    end
  end
end


# require "../checklist2"
# a = Klaxon::Checks.new
# a.list.each do |i|
#   q = Klaxon::Query.new(query: i.query)
#   puts
#   puts i.name
#   puts q.to_s
# end

# m = [
#   { "kubernetes.labels.app" => "org-nginx-routing" },
#   { "kubernetes.namespace" => "org-prod" }
# ]
# a = {
#   "request_time" => "nginx_routing.request_time"
# }
# r = { gte: "now - 10m", lte: "now" }
# q = Klaxon::Query.new(matchers: m, aggs: a, range: r)
# puts q.query

# puts q.range
# puts ""
# q.range = { gte: "now - 60m", lte: "now" }
# puts q.query
# puts q.range
# puts ""
# q.range = { gte: "now - 1y", lte: "now" }
# puts q.query
# puts q.range
