# Backburner Hooks

You can customize Backburner or write plugins using its hook API.
In many cases you can use a hook rather than mess around with Backburner's internals.

## Job Hooks

Hooks are transparently adapted from [Resque](https://github.com/resque/resque/blob/master/docs/HOOKS.md), so
if you are familiar with their hook API, now you can use nearly the same ones with beanstalkd and backburner!

There are a variety of hooks available that are triggered during the lifecycle of a job:

* `before_enqueue`: Called with the job args before a job is placed on the queue.
  If the hook returns `false`, the job will not be placed on the queue.

* `after_enqueue`: Called with the job args after a job is placed on the queue.
  Any exception raised propagates up to the code which queued the job.

* `before_perform`: Called with the job args before perform. If a hook returns false,
  the job is aborted and deleted from the queue. Other exceptions are treated like regular job exceptions.

* `after_perform`: Called with the job args after it performs. Uncaught
  exceptions will be treated like regular job exceptions.

* `around_perform`: Called with the job args. It is expected to yield in order
	to perform the job (but is not required to do so). It may handle exceptions
	thrown by perform, but uncaught exceptions will be treated like regular job exceptions.

* `on_retry`: Called with the retry count, the delay and the job args whenever a job is retried.

* `on_bury`: Called with the job args when the job is buried.

* `on_failure`: Called with the exception and job args if any exception occurs
  while performing the job (or hooks).

Hooks are just methods prefixed with the hook type. For example:

```ruby
class SomeJob
  def self.before_perform_log_job(*args)
    logger.info "About to perform #{self} with #{args.inspect}"
  end

  def self.on_failure_log_job(e, *args)
    logger.info "Performing #{self} caused an exception (#{e})"
  end

  def self.perform(*args)
    # ...
  end

  def self.logger
    @_logger ||= Logger.new(STDOUT)
  end
end
```

A failure hook doesn't need to retry or bury the job: the worker retries a failed job up to `max_job_retries`
times and then buries it. Use an `on_retry` or `on_bury` hook to act on those.

You can also setup modules to create compose-able and reusable hooks for your jobs. For example:

```ruby
module LoggedJob
  def before_perform_log_job(*args)
    puts "About to perform #{self} with #{args.inspect}"
  end
end

module NotifiedJob
  def on_failure_notify(e, *args)
    puts "Performing #{self} caused an exception (#{e})"
  end
end

class MyJob
  extend LoggedJob
  extend NotifiedJob

  def self.perform(*args)
    # ...
  end
end
```

## Worker Hooks

Currently, there is just one hook:

* `on_reconnect`: Called on the worker whose connection has been reset. The connection
  is given as the argument. Every method whose name starts with `on_reconnect` is called,
  so add your own as `on_reconnect_<something>`. The Simple, Forking and ThreadsOnFork
  workers define `on_reconnect` itself to watch their tubes again; if you override
  `on_reconnect` in a subclass of one of them, call `super`.

An example:

```ruby
class MyWorker < Backburner::Workers::Simple
  def on_reconnect_log(conn)
    log_info "reconnected to beanstalkd"
  end
end
```
