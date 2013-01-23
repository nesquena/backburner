# CHANGELOG

## Version 0.3.3 (Unreleased)

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