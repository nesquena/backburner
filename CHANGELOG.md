# CHANGELOG

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
