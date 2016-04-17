# encoding: utf-8

require 'thread'
require 'tty/command/version'
require 'tty/command/cmd'
require 'tty/command/process_runner'
require 'tty/command/printers/pretty'
require 'tty/command/printers/progress'

module TTY
  class Command
    ExecuteError = Class.new(StandardError)

    TimeoutExceeded = Class.new(StandardError)

    FailedError = Class.new(RuntimeError)

    attr_reader :printer

    # Initialize a Command object
    #
    # @param [Hash] options
    # @option options [IO] :output
    #   the stream to which printer prints, defaults to stdout
    # @option options [Symbol] :printer
    #   :text, :logger
    #
    # @api public
    def initialize(options = {})
      @output = options.fetch(:output) { $stdout }
      color   = options.fetch(:color) { true }
      name    = options.fetch(:printer) { :pretty }

      @printer = use_printer(name).new(@output, color: color)
      @runner  = ProcessRunner.new(@printer)
    end

    # Start external executable in a child process
    #
    # @example
    #   cmd.execute(command, [argv1, ..., argvN], [options])
    #
    # @param [String] command
    #   the command to execute
    #
    # @param [Array[String]] argv
    #   an array of string arguments
    #
    # @param [Hash] options
    #   hash of operations to perform
    #
    # @option options [String] :chdir
    #   The current directory.
    # @option options [Integer] :timeout
    #   Maximum number of seconds to allow the process
    #   to execute before aborting with a TimeoutExceeded
    #   exception.
    #
    # @api public
    def execute(*args)
      cmd = Cmd.new(*args)
      yield(cmd) if block_given?
      mutex = Mutex.new
      mutex.synchronize { @runner.run(cmd) }
    end

    # Throw exception when failed
    #
    # @example
    #   cmd.execute!(command, [argv1, ..., argvN], [options])
    #
    # @raise [FailedError]
    #   raised when command exits with non-zero code
    #
    # @api public
    def execute!(*args)
      name = nil
      result = execute(*args) do |cmd|
        name = cmd.to_command
      end
      if result && result.failure?
        raise FailedError,
              "Invoking `#{name}` failed with status #{result.exit_status}"
      end
    end

    private

    # @api private
    def use_printer(class_or_name, *args)
      if class_or_name.is_a?(Class)
        class_or_name
      else
        find_printer_class(class_or_name)
      end
    end

    # Find printer class or fail
    #
    # @raise [ArgumentError]
    #
    # @api private
    def find_printer_class(name)
      const_name = name.to_s.capitalize.to_sym
      unless TTY::Command::Printers.const_defined?(const_name)
        fail ArgumentError, %Q{Unknown printer type "#{name}"}
      end
      TTY::Command::Printers.const_get(const_name)
    end
  end # Command
end # TTY
