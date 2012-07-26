God.watch do |w|
  w.name   = "backburner-worker-1"
  w.dir    = '/path/to/app/dir'
  w.env = { 'PADRINO_ENV' => 'production', 'QUEUES' => 'newsletter-sender,push-message' }
  w.group    = 'backburner-workers'
  w.interval = 30.seconds
  w.start = "bundle exec rake -f Rakefile backburner:start"
  w.log   = "/var/log/god/backburner-worker-1.log"

  # restart if memory gets too high
  w.transition(:up, :restart) do |on|
    on.condition(:memory_usage) do |c|
      c.above = 50.megabytes
      c.times = 3
    end
  end

  # determine the state on startup
  w.transition(:init, { true => :up, false => :start }) do |on|
    on.condition(:process_running) do |c|
      c.running = true
    end
  end

  # determine when process has finished starting
  w.transition([:start, :restart], :up) do |on|
    on.condition(:process_running) do |c|
      c.running = true
      c.interval = 5.seconds
    end

    # failsafe
    on.condition(:tries) do |c|
      c.times = 5
      c.transition = :start
      c.interval = 5.seconds
    end
  end

  # start if process is not running
  w.transition(:up, :start) do |on|
    on.condition(:process_running) do |c|
      c.running = false
    end
  end
end