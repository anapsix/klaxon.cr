require "yaml"
require "./log"

class Klaxon
  CONFIG = Config.new
  class_property config = CONFIG

  struct Config
    include Klaxon::Log

    struct Elasticsearch
      include YAML::Serializable
      # include YAML::Serializable::Unmapped

      @[YAML::Field(key: "host", emit_null: true)]
      getter host : String = ENV.fetch("ELASTICSEARCH_HOST", "localhost")

      @[YAML::Field(key: "port", emit_null: true)]
      getter port : UInt16 = ENV.fetch("ELASTICSEARCH_PORT", "9200").to_u16

      @[YAML::Field(key: "username", emit_null: true)]
      getter username : String? = ENV.fetch("ELASTICSEARCH_USERNAME", nil)

      @[YAML::Field(key: "password", emit_null: true)]
      getter password : String? = ENV.fetch("ELASTICSEARCH_PASSWORD", nil)

      @[YAML::Field(key: "tls")]
      getter tls : Bool = case ENV.fetch("ELASTICSEARCH_TLS", "false")
                          when "true", "yes", "enabled", "on", "1"
                            true
                          else
                            false
                          end

      def initialize(
        host : String | Nil = nil,
        port : Int32 | UInt16 | Nil = nil,
        username : String | Nil = nil,
        password : String | Nil = nil,
        tls : Bool | Nil = nil)
        @host ||= ENV.fetch("ELASTICSEARCH_HOST", "localhost")
        @port ||= ENV.fetch("ELASTICSEARCH_PORT", "9200").to_u16
        @username ||= ENV.fetch("ELASTICSEARCH_USERNAME", nil)
        @password ||= ENV.fetch("ELASTICSEARCH_PASSWORD", nil)
        @tls ||=  case ENV.fetch("ELASTICSEARCH_TLS", "false")
                  when "true", "yes", "enabled", "on", "1"
                    true
                  else
                    false
                  end
      end
    end

    struct SMTP
      include YAML::Serializable

      @[YAML::Field(key: "host", emit_null: true)]
      getter host : String = ENV.fetch("SMTP_HOST", "localhost")

      @[YAML::Field(key: "port", emit_null: true)]
      getter port : Int32 = ENV.fetch("SMTP_PORT", "25").to_i32

      def initialize(
        host : String | Nil = nil,
        port : Int32 | Nil = nil)
        @host ||= ENV.fetch("SMTP_HOST", "localhost")
        @port ||= ENV.fetch("SMTP_PORT", "25").to_i32
      end
    end

    struct Data
      include YAML::Serializable

      @[YAML::Field(key: "elasticsearch")]
      getter elasticsearch : Elasticsearch = Klaxon::Config::Elasticsearch.new

      @[YAML::Field(key: "smtp")]
      getter smtp : SMTP = Klaxon::Config::SMTP.new
    end

    getter elasticsearch : Elasticsearch
    getter smtp : SMTP
    getter file : String? = nil

    def initialize(file : String | Nil = nil)
      file ||= ENV.fetch("KLAXON_CONFIG", "./config.yaml")
      if File.readable?(file)
        @file = file
        config_data = Klaxon::Config::Data.from_yaml(File.read(file))
        @elasticsearch = config_data.elasticsearch
        @smtp = config_data.smtp
      else
        warn "#{file} is not readable, using config from environment with defaults"
        @elasticsearch = Klaxon::Config::Elasticsearch.new
        @smtp = Klaxon::Config::SMTP.new
      end

      if @elasticsearch.username.to_s.empty? || @elasticsearch.password.to_s.empty?
        STDERR.puts "expecting both ES username and ES password, when one is set"
        exit 1
      end
    end
  end
end
