# CHANGELOG

## Unreleased

* Fix "Worker exiting..." never being logged when a worker stops on `TERM` or `INT`: the process exited before the thread that logs it ran. The worker now waits up to a second for that line to be written before it exits. **What to do:** nothing

## Version 1.8.0 (Oct 31 2026)

* Fix ThreadsOnFork and Forking children crashing on Ruby 3.3 with `[BUG] lazy sweeping underway when freeing object space` when they stopped on a `TERM` or `INT`, on an error, or when a job called `exit`, if a thread in the parent was running finalizers when the child was forked (an interpreter bug fixed in Ruby 3.4). On Ruby 3.3 a forked child now disables the GC as it exits, so its `at_exit` handlers (the app's, and those it inherited from the parent) run with the GC off, and a child running several threads stops its job threads before those handlers run (a job they were working on goes back to the queue and runs again). Other Rubies are unchanged. **What to do:** nothing; on Ruby 3.3 an `at_exit` handler that allocates a lot in a child now grows the child's memory until it exits
* Fix a delay of a fraction of a second being cut short: `delay` is now rounded up to whole seconds instead of down, so a job never becomes ready before its delay is up. Before, `delay: 0.5` enqueued a job that was ready at once, and an Active Job `set(wait: 1)` or `set(wait_until: ...)`, whose delay is always a little under the time asked for once it reaches the adapter, ran up to a second early (`wait: 1` ran at once). Whole-second delays are unchanged; a fractional one now waits up to a second longer than asked, never less. A fractional retry delay (a `retry_delay_proc` that returns a Float, or a Float `config.retry_delay`) is rounded up the same way; before, beanstalkd refused it (`Beaneater::BadFormatError`), which stopped the worker (the simple worker exited, and a ThreadsOnFork or Forking child died) instead of retrying the job. A fractional TTR (`:ttr` when enqueueing, a class's `queue_respond_timeout` or `config.respond_timeout`) is rounded up to whole seconds too; a Float `config.respond_timeout` used to fail every enqueue (`Beaneater::BadFormatError`). **Behaviour change:** a Float `:ttr`, `queue_respond_timeout` or `queue_retry_delay` (such as `queue_retry_delay 1.5`) used to be ignored in favour of the global default (`config.respond_timeout`, `config.retry_delay`); it is now used, rounded up. The same goes for a fractional `ActiveSupport::Duration` or Rational (`queue_respond_timeout 1.5.minutes` now gives a TTR of 90 instead of the default). If you set one by mistake, remove it to keep the default. `on_retry` hooks now get the rounded delay, and a `retry_delay_proc` that returns `nil`, a String that isn't a number, or a negative number now retries at once (delay 0) instead of stopping the worker with `Beaneater::BadFormatError`; a `:ttr`, `queue_respond_timeout` or `queue_retry_delay` that isn't finite (`Float::INFINITY`, `NaN`) is still ignored in favour of the default
* Fix a ThreadsOnFork child running more than one thread (`threads_number` or a tube's threads limit above 1) with `garbage_after` set stopping after its first `garbage_after` jobs on Ruby 3.2 and newer: once its threads had worked them, it waited for every thread in the process to finish, including the one the `timeout` gem keeps running since Ruby 3.2 (`timeout` 0.3), so it never exited to be forked again and the tube's jobs piled up. It now waits only for its own threads, so a thread a job leaves running no longer holds it up either. Ruby 3.1 and older with their bundled `timeout` weren't affected. **What to do:** nothing; a worker stuck this way recovers once upgraded and restarted
* Fix the usage comment in `bin/backburner`: queues are given with `-q` (`backburner -q foo,bar`); a bare `backburner foo,bar` ignores them and works every known queue
* Fix the ThreadsOnFork worker logging "Catastrophic failure: tube ... exited with code 0" for every child on a normal shutdown: while the worker shuts down, a child that exits with code 0 is now logged as "Tube ... exited normally.", and one that exits with another code or is killed (by the shutdown's `SIGKILL`) as "Tube ... stopped.", without being forked again. A child that exits with code 0 at another time (a signal sent to the child alone, or a job that called `exit`) is logged as a warning, "Tube ... exited with code 0. Forking it again in Ns."
* Fix an error raised by `config.on_error` (an error reporter that can't reach its service, say) stopping the worker: it escaped `work_one_job`, which ended the simple worker and killed a ThreadsOnFork or Forking child; it is now logged ("The on_error handler failed for ..."). The failed job is still retried or buried as before
* Fix the ThreadsOnFork worker forking children in a busy loop when they fail at once (hundreds a second while beanstalkd is down, each logging a "Catastrophic failure"): after a child fails, the parent now waits 1 second before forking the next one, doubling up to 30 seconds while children keep failing, and starts over once a child is recycled or runs for 30 seconds; recycling a child after `garbage_after` jobs is still immediate. A child running several threads now exits with code 1 (instead of 99) when one of its threads died of an error, so it backs off too
* Fix a job whose class can't be found or fails to load stopping the worker: the `Backburner::Job::JobNotFound` raised while handling its failure escaped `work_one_job` (so the simple worker exited and a ThreadsOnFork child died and was forked again in a busy loop), and so did any error other than a `NameError` raised while its class's file loaded (a `LoadError`, `KeyError`, `SyntaxError` and so on). When the class is missing (renamed or removed, or enqueued by code deployed before the workers: there is no such constant, or its autoload file isn't there), the worker now logs a warning ("... class not found; released for Ns") and releases the job with a delay of its TTR (at most 60 seconds), so a worker that has the class picks it up; it is never buried for this and doesn't use up its retries (beanstalkd still counts the releases, so a later failure gets fewer retries), and `on_error` and the failure hooks aren't called for it, as before. **What to do:** jobs of a class you removed on purpose now keep coming back, with a warning each time, instead of stopping the worker: delete them (with a beanstalkd client, say) or keep a stub class whose `perform` does nothing until they are drained. When the class's file fails to load (it raises a `NameError` for another constant, `NoMethodError`, `ArgumentError` or any other error, has a syntax error, or requires a missing gem), or the job names something that can't be a class (`"not a class"`), the job fails like any other: it is retried and then buried, `on_error` gets the `JobNotFound`, and its message names the cause on one line (`JobNotFound: SomeJob (LoadError: cannot load such file -- some_gem)`). **What to do:** fix the file and deploy, then kick the buried jobs
* Fix `handle_asynchronously` and `handle_static_asynchronously` wiping the class's queue settings: its jobs went to the primary queue (`backburner-jobs`) with the default priority and TTR instead of the class's `queue`, `queue_priority` and `queue_respond_timeout`. Including `Backburner::Performable` in a class that already includes `Backburner::Queue` no longer resets the settings it set either. **Behaviour change:** jobs of a class that calls `handle_asynchronously`/`handle_static_asynchronously` (including its `async` calls) now use the class's `queue`, `queue_priority` and `queue_respond_timeout` (before, the settings declared ahead of the call were lost). Workers started with `-q` or `default_queues` must also watch the class's tube (a worker started with no queues already does). Jobs enqueued before the upgrade stay on the primary queue, so keep a worker on it until they are drained
* Fix apps on Rails 6.1, 7.0 and 7.1 failing to boot with backburner 1.7.0 (`uninitialized constant ActiveJob::QueueAdapters::AbstractAdapter` from `require 'backburner'`, or from `config.active_job.queue_adapter = :backburner`): the gem's Active Job adapter subclasses `AbstractAdapter` only on Rails 7.2+, which added it, and `require 'backburner'` loads it only there; older Rails autoload the adapter as before. Where the gem's adapter loads in place of Rails' own (whenever the gem's lib comes first on the load path, as Bundler puts it), it also sets `provider_job_id` on Rails 6.1 and 7.0. The adapter now requires backburner itself, as Rails' own adapter did, so apps with `gem 'backburner', require: false` can enqueue again (since 1.7.0 the first enqueue raised `uninitialized constant Backburner::Worker`). CI now also runs the suite with Active Job 6.1
* Fix a worker started without queues (`backburner` with no `-q`) never working the tubes it found on the server when the namespace has capitals (`MyApp`), an underscore or regexp characters (`jobs(eu)`, `app+`), when the separator isn't `.`, or for queue names such as ActiveJob's `production_mailers` under the namespace `production` (tube `production.-mailers`) and `report_2026`: it expanded those tube names again and watched tubes nobody enqueues on (`MyApp.my-app.default` instead of `MyApp.default`). It now watches the server's tubes this configuration could have produced (they start with the namespace and separator, and the rest has no capitals or underscores), under their own names, and a found tube with `--` in its name (queue `a__b`) no longer stops it at start with `NoMethodError`. The tube names jobs are enqueued on don't change
* Fix a `tube_namespace` that isn't a valid regexp (such as `app(`) failing every enqueue and stopping workers with `RegexpError`
* Fix `namespace_separator = ''` failing every enqueue with `RegexpError`: the namespace and the queue name are now joined directly (`appdefault`, or `app.default` for the namespace `app.`)
* Fix a failing job stopping the worker when it runs in a directory whose name has regexp characters (such as `jobs[`): logging the error raised `RegexpError`
* Fix ThreadsOnFork with one thread per tube: each forked child now opens its own beanstalkd connection instead of sharing the parent's socket, which mixed up replies between children (`undefined method 'ttr' for nil`, lost jobs) (reported by @Haerezis in #169 and @supremoUL in #175)
* Fix workers never recovering after beanstalkd is down for more than a few seconds: a failed reconnect no longer leaves the connection unusable (`undefined method 'tubes'` in a busy loop), and the simple worker watches its tubes again after reconnecting; a job that fails while the connection is down no longer stops the simple worker either. A job that finishes while beanstalkd can't be reached (past beaneater's reconnect attempts) can't be deleted: `on_error` gets the `Beaneater::NotConnected`, and beanstalkd hands the job out again if it still has it (reported by @activestylus in #137)
* Fix `Connection#retryable` raising `NameError` instead of `Beaneater::NotConnected` once its retries are used up
* Fix a job that outlives its TTR stopping the worker: when beanstalkd has already taken the job back, the `NOT_FOUND` from the retry or bury is now logged instead of escaping `work_one_job` (reported by @boncey in #82)
* Behaviour change: a `before_perform` hook returning false now deletes the job, as HOOKS.md describes; before, the job stayed reserved and beanstalkd handed it out again after every TTR (reported by @inoce1e in #145)
* Fix docs: a TTR of 0 does not disable the timeout, beanstalkd stores it as 1 (reported by @pnabutovsky in #126); the HOOKS.md failure-hook examples no longer call `self.bury`, which raised `NoMethodError` and hid the original error (reported by @contentfree in #172); the README no longer points to the removed `retry_connection!` (reported by @att14 in #62)
* Fix queue settings not being inherited: a subclass of a `Backburner::Queue` job class now uses its parent's `queue`, `queue_priority`, `queue_respond_timeout`, `queue_max_job_retries`, `queue_retry_delay`, `queue_retry_delay_proc`, `queue_jobs_limit`, `queue_garbage_limit` and `queue_retry_limit` unless it sets its own, and is registered in `Backburner::Worker.known_queue_classes` (anonymous classes, such as `Class.new(SomeJob)`, are left out when workers list the known queues). For the Threading and ThreadsOnFork workers, a tube's `queue_jobs_limit`, `queue_garbage_limit` and `queue_retry_limit` come from the class that declares the tube; subclasses that share it only fill in the limits it leaves unset. **Behaviour change:** a subclass that didn't set `queue` used to enqueue on the primary queue (`backburner-jobs`); it now enqueues on its parent's queue (tube). Jobs it enqueued before the upgrade stay on the primary queue, so keep a worker on that tube until they are drained. A subclass can't unset an inherited setting: the setters ignore `nil` and `false` (reported by @contentfree in #141)
* Fix every enqueue opening a new TCP connection to beanstalkd (closed sockets piled up in `TIME_WAIT` until enqueueing failed with `Beaneater::NotConnected`): enqueueing reuses pooled connections (up to 5 idle per process, each reused for up to `config.enqueue_connection_max_idle` seconds, default 60), a forked child opens its own, and a connection that an error interrupted is closed rather than reused. While beanstalkd is down, each enqueue that picks up an idle pooled connection (up to 5) now takes about 2 seconds of retries before raising `Beaneater::NotConnected`, instead of failing at once; later ones fail at once (reported by @xinuc in #125, confirmed by @funkyboy)
* Allow `config.tube_namespace = nil` (or `false`) for tubes without a prefix: jobs go to `backburner-jobs`, `newsletter-sender` and so on. `nil` and `false` used to raise `NoMethodError`; `''` still gives tube names that start with the separator (`.backburner-jobs`), as before. With no namespace, a worker started without tubes watches every tube on the server without capitals or underscores (including `default`), so give your tubes distinct names on a shared beanstalkd (@forresty in #94)
* Fix `config.default_priority` set to a priority label (such as `:high`) failing every enqueue with `Beaneater::BadFormatError`: the label now resolves like a job's priority label (reported by @rewritten in #52, tracked in #54)
* Fix `require 'backburner'` on Ruby 4.0 in a bundle without ActiveSupport (`cannot load such file -- logger`): `logger` is no longer a default gem, so the gemspec now depends on it
* Require Ruby 2.7 or newer (the gemspec now says so; CI covers 2.7 to 4.0)

## Version 1.7.0 (Jan 2 2026)

* Changes to ActiveJob Rails adapter to remove default adapter and associated tests

## Version 1.6.1 (Jan 16 2023)

* Change `File.exists?`` to `File.exist?` as latest ruby versions have removed support (@ShrutiSaagar).

## Version 1.6.0 (December 30 2021)

* TBD (please help backfill)

## Version 1.5.0 (September 10 2018)

* TBD

## Version 1.4.1 (June 10 2017)

* Fix warning for constant ::Fixnum is deprecated (@amatsuda)

## Version 1.4.0 (May 13 2017)

* Fix unit tests to be more consistent (@eltone)
* Ensure job supports body hash with symbol keys (@eltone)
* Add support for custom serialization formats (@eltone)
* Log the params when a job timeout occurs (@nathantsoi)

## Version 1.3.1 (April 21 2016)

* Addition of thread-pool-based concurrency (@contentfree)

## Version 1.3.0 (February 05 2016)

* Enqueue command now responds with beanstalk response details

## Version 1.2.0 (November 01 2015)

* FIX Made connections to beanstalkd more resilient (@contentfree)

## Version 1.2.0.pre (October 24 2015)

 * FIX Replace static Beaneater connection with individual connections per worker instance/thread (@contentfree)
 * FIX Beaneater connections try really hard to repair themselves if disconnected accidentally (@contentfree)
 * NEW Event hook for workers: on_reconnect (@contentfree)

## Version 1.1.0 (September 14 2015)

 * NEW Ability to configure namespace separator (@bfolkens)
 * NEW Avoid timeouts altogether by setting queue_respond_timeout to 0 (@zacviandier)
 * NEW Event hooks for on_retry and on_bury (@contentfree)
 * NEW Support lambdas for queue names (@contentfree)
 * NEW Allow for control of delay calculation (@contentfree)
 * NEW Ability to specify environment when running the CLI (@contentfree)
 * NEW Control default async behavior of methods (@contentfree)

## Version 1.0.0 (April 26 2015)

 * NEW Updating to Beaneater 1.0 (@alup)

## Version 0.4.6 (October 26 2014)

 * NEW Add job to on_error handler if the handler has a 4th argument (@Nitrodist)
 * NEW Use a timeout when looking for a job to reserve (@EasyPost)
 * NEW Support configuring settings on threads on fork class (@silentshade)
 * FIX queue override by existing queues (@silentshade)
 * FIX Use thread to log exit message (@silentshade)

## Version 0.4.5 (December 16 2013)

 * FIX #47 Create a backburner connection per thread (Thanks @thcrock)

## Version 0.4.4 (October 27 2013)

 * NEW #51 Added ability to set per-queue default ttr's (Thanks @ryanjohns)

## Version 0.4.3 (July 19 2013)

 * FIX #44 Additional fix to issue introduced in 0.4.2
 * FIX #45 More graceful shutdown using Kernel.exit and rescuing SystemExit. (Thanks @ryanjohns)

## Version 0.4.2 (July 3 2013)

 * FIX #44 Properly retry to connect to beanstalkd when connection fails.

## Version 0.4.1 (June 28 2013)

 * FIX #43 Properly support CLI options and smart load the app environment.

## Version 0.4.0 (June 28 2013)

NOTE: This is the start of working with @bradgessler to improve backburner and merge with quebert

 * NEW #26 #27 Remove need for Queue mixin, allow plain ruby objects
 * NEW Default all jobs to a single general queue rather than separate queues
 * NEW Add support for named priorities, allowing shorthand names for priority values

## Version 0.3.4 (April 23 2013)

 * FIX #22 Adds signal handlers for worker to manage proper shutdown (Thanks @tkiley)

## Version 0.3.3 (April 19 2013)

 * Fix naming conflict rename 'config' to 'queue_config'

## Version 0.3.2 (Jan 23 2013)

 * Bump version of beaneater to 0.3.0 (better socket handling)

## Version 0.3.1 (Dec 28 2012)

 * Adds basic forking processing strategy and rake tasks (Thanks @danielfarrell)

## Version 0.3.0 (Nov 14 2012)

 * Major update with support for a 'threads_on_fork' processing strategy (Thanks @ShadowBelmolve)
 * Different workers have different rake tasks (Thanks @ShadowBelmolve)
 * Added processing strategy specific examples i.e stress.rb and adds new unit tests. (Thanks @ShadowBelmolve)

## Version 0.2.6 (Nov 12 2012)

 * Upgrade to beaneater 0.2.0

## Version 0.2.5 (Nov 9 2012)

 * Add support for multiple worker processing strategies through subclassing.

## Version 0.2.0 (Nov 7 2012)

 * Add new plugin hooks feature (see HOOKS.md)

## Version 0.1.2 (Nov 7 2012)

 * Adds ability to specify a custom logger.
 * Adds job retry configuration and worker support.

## Version 0.1.1 (Nov 6 2012)

 * Fix issue with timed out reserves

## Version 0.1.0 (Nov 4 2012)

 * Switch to beaneater as new ruby beanstalkd client
 * Add support for array of connections in `beanstalk_url`
