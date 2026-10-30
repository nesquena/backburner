# CHANGELOG

## Unreleased

* Fix ThreadsOnFork with one thread per tube: each forked child now opens its own beanstalkd connection instead of sharing the parent's socket, which mixed up replies between children (`undefined method 'ttr' for nil`, lost jobs) (reported by @Haerezis in #169 and @supremoUL in #175)
* Fix workers never recovering after beanstalkd is down for more than a few seconds: a failed reconnect no longer leaves the connection unusable (`undefined method 'tubes'` in a busy loop), and the simple worker watches its tubes again after reconnecting; a job that fails while the connection is down no longer stops the simple worker either (reported by @activestylus in #137)
* Fix `Connection#retryable` raising `NameError` instead of `Beaneater::NotConnected` once its retries are used up
* Fix a job that outlives its TTR stopping the worker: when beanstalkd has already taken the job back, the `NOT_FOUND` from the retry or bury is now logged instead of escaping `work_one_job` (reported by @boncey in #82)
* Behaviour change: a `before_perform` hook returning false now deletes the job, as HOOKS.md describes; before, the job stayed reserved and beanstalkd handed it out again after every TTR (reported by @inoce1e in #145)
* Fix docs: a TTR of 0 does not disable the timeout, beanstalkd stores it as 1 (reported by @pnabutovsky in #126); the HOOKS.md failure-hook examples no longer call `self.bury`, which raised `NoMethodError` and hid the original error (reported by @contentfree in #172); the README no longer points to the removed `retry_connection!` (reported by @att14 in #62)
* Fix queue settings not being inherited: a subclass of a `Backburner::Queue` job class now uses its parent's `queue`, `queue_priority`, `queue_respond_timeout`, `queue_max_job_retries`, `queue_retry_delay`, `queue_retry_delay_proc`, `queue_jobs_limit`, `queue_garbage_limit` and `queue_retry_limit` unless it sets its own, and is registered in `Backburner::Worker.known_queue_classes` (anonymous classes, such as `Class.new(SomeJob)`, are left out when workers list the known queues). For the Threading and ThreadsOnFork workers, a tube's `queue_jobs_limit`, `queue_garbage_limit` and `queue_retry_limit` come from the class that declares the tube; subclasses that share it only fill in the limits it leaves unset. **Behaviour change:** a subclass that didn't set `queue` used to enqueue on the primary queue (`backburner-jobs`); it now enqueues on its parent's queue (tube). Jobs it enqueued before the upgrade stay on the primary queue, so keep a worker on that tube until they are drained. A subclass can't unset an inherited setting: the setters ignore `nil` and `false` (reported by @contentfree in #141)
* Fix every enqueue opening a new TCP connection to beanstalkd (closed sockets piled up in `TIME_WAIT` until enqueueing failed with `Beaneater::NotConnected`): enqueueing reuses pooled connections (up to 5 idle per process, each reused for up to `config.enqueue_connection_max_idle` seconds, default 60), a forked child opens its own, and a connection that an error interrupted is closed rather than reused. The first enqueue after beanstalkd goes down now takes about 2 seconds of retries before raising `Beaneater::NotConnected`, instead of failing at once (reported by @xinuc in #125, confirmed by @funkyboy)
* Allow `config.tube_namespace = nil` (or `false` or `''`) for tubes without a prefix: jobs go to `backburner-jobs`, `newsletter-sender` and so on. `nil` and `false` used to raise `NoMethodError` and `''` gave tube names with a leading `.`. If you used `''`, your tubes move from `.foo` to `foo`: keep a worker on the old tubes until they are drained. With no namespace, a worker started without tubes watches every tube on the server (including `default`), so give your tubes distinct names on a shared beanstalkd (@forresty in #94)
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
