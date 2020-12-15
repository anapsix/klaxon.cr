require "colorize"
require "log"

class Klaxon
  LOG = ::Log.for(self, :info)
  module Log
    def debug(msg)
      LOG.debug { msg }
    end

    def info(msg)
      LOG.info { msg }
    end

    def notice(msg)
      LOG.notice { msg }
    end

    def warn(msg)
      LOG.warn { msg }
    end

    def error(msg)
      LOG.error { msg }
    end
  end
end
