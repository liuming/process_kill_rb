require "process_kill/version"

module ProcessKill

  DEFAULT_FLOW = [
    { signal: 'QUIT', interval: [1,2,3,5,8,13] },
    { signal: 'TERM', max_retry: 5 },
    { signal: 'KILL', max_retry: 3, interval: 5 },
  ].freeze

  def self.compile_flow(flow)
    result = flow.map do |step|
      intervals = if step[:interval].kind_of?(Array) && step[:max_retry]
        step[:interval].slice(0, step[:max_retry])
      elsif step[:interval].kind_of?(Array) && !step[:max_retry]
        step[:interval]
      elsif step[:interval].kind_of?(Fixnum) && step[:max_retry]
        [step[:interval]] * step[:max_retry]
      elsif step[:max_retry]
        [1] * step[:max_retry]
      else
        [1]
      end
      {signal: step[:signal], intervals: intervals}
    end
  end

  def self.generate_result_template(pids, flow)
    stats_template = flow.map{ {attempts: [], killed: false, resolved: false} }
    template = pids.reduce({}) do |hash, pid|
      hash.merge!(pid => stats_template.dup)
    end

    return template
  end

  def self.execute(pids, flow=nil)
    result = generate_result_template(pids, flow || DEFAULT_FLOW)
    compiled_flow = compile_flow(flow || DEFAULT_FLOW)
    compiled_flow.each_with_index do |step, step_index|
      step[:intervals].each do |interval|
        pids.each do |pid|
          result_item = result[pid][step_index]
          next if result_item[:resolved]
          result[pid][step_index][:signal] = step[:signal]
          begin
            result[pid][step_index][:attempts] << interval # increase attempts counter
            ProcessKill.kill(step[:signal], pid) # send signal
            ProcessKill.sleep(interval) # sleep before next interval
          rescue ProcessNotFoundError => e
            result_item[:killed] = true
            result_item[:resolved] = true
          rescue UnknownError, ProcessPermissionError => e
            result_item[:resolved] = true
          end
        end
      end
    end

    result
  end

  def self.kill(signal, pid)
    Process.kill(signal, pid)
  rescue Errno::ESRCH => e
    raise ProcessNotFoundError
  rescue Errno::EPERM => e
  end

  def self.sleep(seconds)
    Kernel.sleep(seconds)
  end

  class ProcessNotFoundError < StandardError; end
  class ProcessPermissionError < StandardError; end
  class UnknownError < StandardError; end
end
