require "email"

require "./notification_condition"
require "../config"
require "../log"

class Klaxon
  class EmailNotification

    include Klaxon::Log
    include Klaxon::NotificationCondition

    @check_name : String
    @condition : Condition
    @recipient : String
    @subject : String
    @message : String

    @email : EMail::Message
    @client : EMail::Client

    def initialize(@check_name, @condition, @recipient, @subject, @message)

      EMail::Client.log_level = :error

      config = EMail::Client::Config.new(Klaxon.config.smtp.host, Klaxon.config.smtp.port)
      @client = EMail::Client.new(config)

      email = EMail::Message.new
      email.from("no-reply@example.com")
      email.to(@recipient)
      email.subject(@subject)
      email.message <<-EOM
      #{@message}

      --
      Klaxon
      EOM

      @email = email
    end

    def send
      condition = case @condition
                  when Condition::Recovered
                    "recovery".colorize(:green)
                  when Condition::Failed
                    "failure".colorize(:red)
                  else
                    ""
                  end

      info "{#{@check_name.colorize(:light_blue)}} #{condition} notification sent"
      @client.start do
        send(@email)
      end
    end
  end
end
