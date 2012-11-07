# Backburner Hooks

You can customize Backburner or write plugins using its hook API. 
In many cases you can use a hook rather than mess with Backburner's internals.

## Job Hooks 

Hooks are inspired by [Resque](https://github.com/defunkt/resque/blob/master/docs/HOOKS.md), so
if you are familiar with their hook API, now you can use the same ones with beanstalkd and backburner!

There are a variety of hooks available that are triggered during the lifecycle of a job:

* `before_enqueue`: Called with the job args before a job is placed on the queue.
  If the hook returns `false`, the job will not be placed on the queue.

* `after_enqueue`: Called with the job args after a job is placed on the queue.
  Any exception raised propagates up to the code which queued the job.

* `before_dequeue`: Called with the job args before a job is removed from the queue.
  If the hook returns `false`, the job will not be removed from the queue.

* `after_dequeue`: Called with the job args after a job was removed from the queue.
  Any exception raised propagates up to the code which dequeued the job.

* `before_perform`: Called with the job args before perform. If it raises
  `Backburner::Job::DontPerform`, the job is aborted. Other exceptions
  are treated like regular job exceptions.

* `after_perform`: Called with the job args after it performs. Uncaught
  exceptions will be treated like regular job exceptions.

* `around_perform`: Called with the job args. It is expected to yield in order
  to perform the job. It may handle exceptions thrown by `perform`, but any that are not caught will
  be treated like regular job exceptions.

* `on_failure`: Called with the exception and job args if any exception occurs
  while performing the job (or hooks).

Hooks are just methods prefixed with the hook type. For example:

```ruby
class SomeJob
  def before_perform_log_job(*args)
    Logger.info "About to perform #{self} with #{args.inspect}"
  end

  def on_failure_bury(e, *args)
    Logger.info "Performing #{self} caused an exception (#{e})"
    self.bury
  end

	def self.perform(*args)
	  ...
	end
end
```

## Worker Hooks

Coming soon. What do you need here? Just let me know!

