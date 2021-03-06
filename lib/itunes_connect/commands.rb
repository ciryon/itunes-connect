require "itunes_connect/commands/download"
require "itunes_connect/commands/import"
require "itunes_connect/commands/report"
require "itunes_connect/commands/help"
require "clip"

module ItunesConnect::Commands       # :nodoc:
  class << self
    def for_name(name, clip)
      self.const_get(name.capitalize.to_sym).new(clip)
    rescue NameError => e
      nil
    end

    def all
      [Download, Import, Report, Help]
    end

    def usage(msg)
      $stderr.puts msg if msg
      $stderr.puts "USAGE: itunes_connect [command] [options]"
      ItunesConnect::Commands.all.each do |cmd_cls|
        cli = Clip do |c|
          c.banner = "'#{cmd_cls.to_s.split('::').last.downcase}' command options:"

          cmd_cls.new(c)
        end
        puts(cli.help)
        puts
      end
      exit 1
    end

    def default_clip
      cli = Clip::Parser.new
      cli.flag('v', 'verbose', :desc => 'Make output more verbose')
      cli.flag('g', 'debug', :desc => 'Enable debug output/features (dev only)')
      cli
    end
  end
end
