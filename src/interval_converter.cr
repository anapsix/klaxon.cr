class Klaxon
  module IntervalConverter

    def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
      unless node.is_a?(YAML::Nodes::Scalar)
        node.raise "Expected scalar, not #{node.class}"
      end
      interval_from_string(node.value)
    end

    def self.validate_offset(time_interval : String) : Nil
      validator = /^\d+[smhd]$/
      raise "'#{time_interval}' format is unsupported, must match #{validator.inspect}" unless time_interval.match(validator)
    end

    def self.interval_from_string(time_interval) : Time::Span | Nil
      validate_offset(time_interval)
      md = time_interval.match(/(\d+)\s*?([smhd])/)
      md_a = md ? md.to_a : Array(String).new
      raise "failed to parse time_interval '#{time_interval}'" if md_a.empty?
      amount = md_a[1]?
      measure = md_a[2]?
      raise "amount cannot be Nil" if amount.nil?
      raise "measure cannot be Nil" if measure.nil?
      amount = amount.to_u16
      case measure
      when "s"
        amount.seconds
      when "m"
        amount.minutes
      when "h"
        amount.hours
      when "d"
        amount.days
      end
    end
  end
end
