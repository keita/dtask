require "net/ssh"
require "singleton"

class DTask
  VERSION = "002"

  # Command error.
  class Error < StandardError; end

  # DTask configuration.
  class Config
    include Singleton

    def initialize; @table = Hash.new; end

    def self.method_missing(name, *args)
      if md = /(.+)=$/.match(name.to_s)
        instance.instance_eval { @table[name] = args.first }
      else
        instance.instance_eval { @table[name] }
      end
    end

    private

    def o(table); table.each {|key, val| @table[key] = val }; end
  end

  class Remote
    attr_reader :out, :err

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

    # Run the command or call the task.
    def l(cmd)
      cmd.kind_of?(Symbol) ? DTask.run(cmd) : sh(cmd)
    end

    # Ignore errors.
    def l!(cmd)
      begin l(cmd) rescue Error end
    end

    # Run the command.
    def sh(cmd)
      puts "% #{cmd}"
      res = @shell.send_command(cmd)
      pout res.stdout if res.stdout and res.stdout.size > 0
      perr res.stderr if res.stderr and res.stderr.size > 0
      @out << res.stdout
      @err << res.stderr
      res.status == 0 ? res.stdout : (raise Error)
    end

    # Change the current to application directory.
    def cd_appdir
      l "cd #{Config.appdir} && pwd"
    end

    private

    # Print stdout.
    def pout(msg)
      puts "OUT> #{msg}"
    end

    # Print stderr.
    def perr(msg)
      puts "ERR> #{msg}"
    end
  end

  # task table
  TASK = Hash.new

  # Load the dtask file.
  def initialize(name)
    load File.expand_path("~/.dtask/#{name}.dtask")
    @remote = Remote.new
  end

  # Run the task.
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
  # Defines a task.
  def task(name, &block)
    DTask::TASK[name] = block
  end

  # Setup the DTask configuration.
  def setup(&block)
    DTask::Config.instance.instance_eval(&block)
  end
end
