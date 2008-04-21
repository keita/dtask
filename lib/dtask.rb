require "net/ssh"
require "singleton"

class DTask
  VERSION = "001"

  class Error < StandardError; end

  class Config
    include Singleton

    def initialize; @table = Hash.new; end
    def o(table); table.each {|key, val| @table[key] = val }; end

    class << self
      def method_missing(name, *args)
        if md = /(.+)=$/.match(name.to_s)
          instance.instance_eval { @table[name] = args.first }
        else
          instance.instance_eval { @table[name] }
        end
      end
    end
  end

  class Remote
    attr_reader :out
    attr_reader :err

    def initialize
      options = {
        :username => Config.user,
        :auth_methods => "publickey"
      }
      @session = Net::SSH.start(Config.server, options)
      @shell = @session.shell.sync
      @out = []
      @err = []
    end

    def pout(msg)
      puts "OUT> #{msg}"
    end

    def perr(msg)
      puts "ERR> #{msg}"
    end

    def l(cmd)
      cmd.kind_of?(Symbol) ? DTask.run(cmd) : sh(cmd)
    end

    def l!(cmd)
      begin l(cmd) rescue Error end
    end

    def sh(cmd)
      puts "% #{cmd}"
      res = @shell.send_command(cmd)
      pout res.stdout if res.stdout and res.stdout.size > 0
      perr res.stderr if res.stderr and res.stderr.size > 0
      @out << res.stdout
      @err << res.stderr
      res.status == 0 ? res.stdout : (raise Error)
    end

    def cd_appdir
      l "cd #{Config.appdir} && pwd"
    end
  end

  TASK = Hash.new

  def initialize(name)
    load File.expand_path("~/.dtask/#{name}.dtask")
    @remote = Remote.new
  end

  def run(task)
    if TASK.key?(task)
      puts "#{Config.server} >>> #{task}"
      @remote.cd_appdir
      @remote.instance_eval &TASK[task]
    else
      puts "No such task: #{task}"
    end
  end
end

module Kernel
  def task(name, &block)
    DTask::TASK[name] = block
  end

  def setup(&block)
    DTask::Config.instance.instance_eval(&block)
  end
end
