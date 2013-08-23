# Backburner Hooks

You can customize Backburner or write plugins using its hook API. 
In many cases you can use a hook rather than mess around with Backburner's internals.

## Job Hooks 

Hooks are transparently adapted from [Resque](https://github.com/defunkt/resque/blob/master/docs/HOOKS.md), so
if you are familiar with their hook API, now you can use nearly the same ones with beanstalkd and backburner!

There are a variety of hooks available that are triggered during the lifecycle of a job:

* `before_enqueue`: Called with the job args before a job is placed on the queue.
  If the hook returns `false`, the job will not be placed on the queue.

* `after_enqueue`: Called with the job args after a job is placed on the queue.
  Any exception raised propagates up to the code which queued the job.

* `before_perform`: Called with the job args before perform. If a hook returns false,
  the job is aborted. Other exceptions are treated like regular job exceptions.

* `after_perform`: Called with the job args after it performs. Uncaught
  exceptions will be treated like regular job exceptions.

* `around_perform`: Called with the job args. It is expected to yield in order
	to perform the job (but is not required to do so). It may handle exceptions
	thrown by perform, but uncaught exceptions will be treated like regular job exceptions.

* `on_failure`: Called with the exception and job args if any exception occurs
  while performing the job (or hooks).

Hooks are just methods prefixed with the hook type. For example:

```ruby
class SomeJob
  def self.before_perform_log_job(*args)
    logger.info "About to perform #{self} with #{args.inspect}"
  end

  def self.on_failure_bury(e, *args)
    logger.info "Performing #{self} caused an exception (#{e})"
    self.bury
  end

  def self.perform(*args)
    # ...
  end
  
  def self.logger
    @_logger ||= Logger.new(STDOUT)
  end
end
```

You can also setup modules to create compose-able and reusable hooks for your jobs.

## Worker Hooks

Coming soon. What do you need here? Just let me know!

