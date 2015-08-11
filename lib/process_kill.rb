require "process_kill/version"

module ProcessKill

  DEFAULT_FLOW = [
    { signal: 'QUIT', interval: [1,2,3,5,8,13] },
    { signal: 'TERM', max_retry: 5, interval: [1,2,3,5,8,13] },
    { signal: 'KILL', max_retry: 3, interval: 5 },
  ].freeze

  def self.compile_flow(flow)
    result = flow.map do |step|
      intervals = if step[:interval].kind_of?(Array)
        step[:max_retry] ? step[:interval].slice(0, step[:max_retry]) : step[:interval]
      else
        [step[:interval]] * step[:max_retry]
      end
      {signal: step[:signal], intervals: intervals}
    end
  end

  def self.execute(pids, flow=DEFAULT_FLOW)
    stats_template = flow.map{ {attempts: [], resolved: false} }
    compiled_flow = compile_flow(flow)

    result = pids.reduce({}) do |hash, pid|
      hash.merge!(pid => stats_template.dup)
    end

    compiled_flow.each_with_index do |step, step_index|
      step[:intervals].each do |interval|
        pids.each do |pid|
          begin
            kill(step[:signal], pid) # send signal first
            result[pid][step_index][:attempts] << interval # then increase counter
            sleep(interval) # sleep before next interval
          rescue ProcessNotFoundError => e
            result[pid][step_index][:resolved] = true
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
  end

  def self.sleep(seconds)
    Kernel.sleep(seconds)
  end

  class ProcessNotFoundError < StandardError
  end
end
