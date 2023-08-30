module Sandbox
  class ContextScript < ContextBase
    SCRIPTS_DIR = "scripts"

    def initialize(game, shell)
      super(game, shell)
      @commands.merge!({
        "run"     => ["run <name>", "Run the script"],
        "list"    => ["list", "List scripts"],
        "jobs"    => ["jobs", "List active scripts"],
        "kill"    => ["kill <id>", "Kill the script"],
        "admin"   => ["admin <id>", "Administrate the script"],
      })
      @jobs = Hash.new
      @jobCounter = 0;
      @logger = Logger.new(@shell)
      @logger.logPrefix = "\e[1;34m\u273f\e[22;34m "
      @logger.logSuffix = "\e[0m"
      @logger.errorPrefix = "\e[1;31m\u273f\e[22;31m "
      @logger.errorSuffix = "\e[0m"
    end

    def completion(text)
      case Readline.line_buffer.lstrip
        when /^run\s+/
          files = Dir.children(SCRIPTS_DIR).sort.grep(/\.rb$/)
          files.map! {|file| file.delete_suffix!(".rb")}
          return files.grep(/^#{Regexp.escape(text)}/)

        when /^(admin|kill)\s+/
          jobs = @jobs.keys.map(&:to_s)
          return jobs.grep(/^#{Regexp.escape(text)}/)
      end
      super
    end

    def exec(words)
      cmd = words[0].downcase
      case cmd

      when "run"
        script = words[1]
        if script.nil?
          @shell.custom_puts("#{cmd}: Specify script name")
          return
        end

        fname = "#{SCRIPTS_DIR}/#{script}.rb"
        unless File.exist?(fname)
          @shell.custom_puts("#{cmd}: No such script")
          return
        end

        Thread.new {run(script, words[2..-1])}
        return

      when "list"
        scripts = Array.new
        Dir.children(SCRIPTS_DIR).sort.each do |child|
          next unless File.file?("#{SCRIPTS_DIR}/#{child}") && child =~ /\.rb$/
          child.sub!(".rb", "")
          scripts.append(child)
        end

        if scripts.empty?
          @shell.custom_puts("#{cmd}: No scripts")
          return
        end

        @shell.custom_puts("Scripts:")
        scripts.each do |script|
          @shell.custom_puts(" #{script}")
        end
        return

      when "jobs"
        if @jobs.empty?
          @shell.custom_puts("#{cmd}: No active jobs")
          return
        end

        @shell.custom_puts("Active jobs:")
        @jobs.each do |k, v|
          @shell.custom_puts(" [%d] %s" % [k, v[:script]])
        end
        return

      when "kill"
        if words[1].nil?
          @shell.custom_puts("#{cmd}: Specify job ID")
          return
        end

        job = words[1].to_i
        unless @jobs.key?(job)
          @shell.custom_puts("#{cmd}: No such job")
          return
        end

        @jobs[job][:instance].finish
        @logger.log("Killed: #{@jobs[job][:script]} [#{job}]")
        @jobs[job][:thread].kill
        script = @jobs[job][:script]
        name = script.capitalize
        @jobs.delete(job)
        Object.send(:remove_const, name) unless @jobs.each_value.detect {|j| j[:script] == script}
        return
        
      when "admin"
        if words[1].nil?
          @shell.custom_puts("#{cmd}: Specify job ID")
          return
        end

        job = words[1].to_i
        unless @jobs.key?(job)
          @shell.custom_puts("#{cmd}: No such job")
          return
        end

        unless @jobs[job][:instance].respond_to?(:admin)
          @shell.custom_puts("#{cmd}: Not implemented")
          return
        end

        @shell.custom_puts("Enter ! to quit")
        prompt = "\e[1;34m#{@jobs[job][:script]}:#{job} \u273f\e[0m "
        loop do
          @shell.reading = true
          line = Readline.readline(prompt, true)
          @shell.reading = false
          break if line.nil?
          line.strip!
          Readline::HISTORY.pop if line.empty?
          next if line.empty?
          break if line == "!"
          unless @jobs.key?(job)
            @logger.error("Job #{job} terminated")
            break
          end
          msg = @jobs[job][:instance].admin(line)
          next if msg.nil? || msg.empty?
          @shell.custom_puts(msg)
        end
        return

      end
            
      super(words)
    end

    def run(script, args)
      job = @jobCounter += 1
      @jobs[job] = {
        :script   => script,
        :thread   => Thread.current,
      }
      fname = "#{SCRIPTS_DIR}/#{script}.rb"
      @logger.log("Run: #{script} [#{job}]")
      
      logger = Logger.new(@shell)
      logger.logPrefix = "\e[1;36m\u276f [#{script}]\e[22;36m "
      logger.logSuffix = "\e[0m"
      logger.errorPrefix = "\e[1;31m\u276f [#{script}]\e[22;31m "
      logger.errorSuffix = "\e[0m"
      logger.infoPrefix = "\e[1;37m\u276f [#{script}]\e[22;37m "
      logger.errorSuffix = "\e[0m"

      begin
        name = script.capitalize
        load "#{fname}" unless Object.const_defined?(name)
        unless Object.const_defined?(name)
          raise "Class #{name} not found"
        end
        @jobs[job][:instance] = Object.const_get(name).new(@game, @shell, logger, args)
        @jobs[job][:instance].main
      rescue => e
        msg = String.new
        (e.backtrace.length - 1).downto(0) do |i|
          msg += "#{i + 1}. #{e.backtrace[i]}\n"
        end
        @logger.error("Error: #{script} [#{job}]\n\n#{msg}\n=> #{e.message}")
      else
        @jobs[job][:instance].finish
        @logger.log("Done: #{script} [#{job}]")
      end

      @jobs.delete(job)
      Object.send(:remove_const, name) if !@jobs.each_value.detect {|j| j[:script] == script} && Object.const_defined?(name)
    end
  end
end

