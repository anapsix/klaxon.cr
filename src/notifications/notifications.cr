require "./email_notification"
require "./notification_condition"
require "../checklist"
require "../log"

class Klaxon

  class Notifications
    FAILURE_THRESHOLD = 3_u8
    MAX_CHECK_HISTORY = 10
    NOTIFICATION_FREQUENCY = 30.minutes

    include Klaxon::NotificationCondition

    # stores check objects by check name
    @@checks = Hash(String, Klaxon::Checks::List::Item).new

    # stores last check conditions by check name
    @@check_conditions = Hash(String, Condition).new

    # stores sent notification timestamps by check name
    @@check_sent_notifications = Hash(String, Time).new

    # stores array of check results by check name
    # { "test" => [false, true, false] }
    @@check_statuses = Hash(String, Array(Bool)).new

    # stores last value by check name
    @@check_values = Hash(String, String).new

    def self.register(check : Klaxon::Checks::List::Item) : Nil
      @@checks[check.name] ||= check
      @@check_statuses[check.name] ||= Array(Bool).new
    end

    def self.checks
      @@checks.dup
    end

    def self.check_statuses
      @@check_statuses.dup
    end

    def self.update_check_status(check_name : String, status : Bool, value : String) : Nil
      @@check_values[check_name] = value
      @@check_statuses[check_name] << status
      @@check_statuses[check_name].shift if @@check_statuses[check_name].size > MAX_CHECK_HISTORY
    end

    private def self.record_recovery(check_name : String) : Nil
      @@check_conditions[check_name] = Condition::Recovered
    end

    private def self.record_failure(check_name : String) : Nil
      @@check_conditions[check_name] = Condition::Failed
    end

    private def self.previously_failed?(check_name : String) : Bool
      return false if @@check_conditions[check_name]?.nil?
      @@check_conditions[check_name] == Condition::Failed
    end

    private def self.triggered?(check_name : String) : Bool
      failure_threshold = @@checks[check_name].notification.failure_threshold.to_i8
      return false if @@check_statuses[check_name]?.nil?
      return false if @@check_statuses[check_name].size < failure_threshold
      last_n = @@check_statuses[check_name].last(failure_threshold)
      last_n == Array(Bool).new(failure_threshold, false)
    end

    private def self.throttled?(check_name : String) : Bool
      return false if @@check_sent_notifications[check_name]?.nil?
      (Time.utc - @@check_sent_notifications[check_name]) <= NOTIFICATION_FREQUENCY
      # now = Time.utc
      # going_out = (now - @@check_sent_notifications[check_name]) >= NOTIFICATION_FREQUENCY
      # info "now: #{now}"
      # info "last sent: #{@@check_sent_notifications[check_name]}"
      # if going_out
      #   info "going out"
      #   return true
      # else
      #   info "not going out"
      #   return false
      # end
    end

    private def self.send_failure(check_name : String) : Nil
      spawn do
        notification = Klaxon::EmailNotification.new(
          check_name: check_name,
          condition: Condition::Failed,
          recipient: @@checks[check_name].notification.recipient.to_s,
          subject: "[FAILED]: #{check_name}",
          message: <<-EOM
          {#{check_name}} check failed #{@@checks[check_name].notification.failure_threshold} times in a row

          #{@@checks[check_name].query.aggs.type}: #{@@check_values[check_name]}
          trigger condition: #{@@check_values[check_name]} #{@@checks[check_name].trigger.operator} #{@@checks[check_name].trigger.threshold}
          EOM
        )
        notification.send
      end
    end

    private def self.send_recovery(check_name : String) : Nil
      spawn do
        notification = Klaxon::EmailNotification.new(
          check_name: check_name,
          condition: Condition::Recovered,
          recipient: @@checks[check_name].notification.recipient.to_s,
          subject: "[RECOVERED]: #{check_name}",
          message: <<-EOM
          {#{check_name}} check recovered

          #{@@checks[check_name].query.aggs.type}: #{@@check_values[check_name]}
          trigger condition: #{@@check_values[check_name]} #{@@checks[check_name].trigger.operator} #{@@checks[check_name].trigger.threshold}
          EOM
        )
        notification.send
      end
    end

    def self.process_notifications : Nil
      @@check_statuses.keys.each do |check_name|
        if triggered?(check_name)
          if previously_failed?(check_name)
            info "{#{check_name.colorize(:light_blue)}} notification suppressed"
            return
          else
            record_failure(check_name)
          end
          if throttled?(check_name)
            info "{#{check_name.colorize(:light_blue)}} notification throttled"
            return
          else
            @@check_sent_notifications[check_name] = Time.utc
          end
          send_failure(check_name)
        else
          if previously_failed?(check_name)
            record_recovery(check_name)
            send_recovery(check_name)
          end
        end
      end
    end
  end
end
