# Backburner

Backburner is a [beanstalkd](http://kr.github.com/beanstalkd/)-powered job queue that can handle a very high volume of jobs.
You create background jobs and place them on multiple work queues to be processed later.

Processing background jobs reliably has never been easier than with beanstalkd and Backburner. This gem works with any ruby-based
web framework, but is especially suited for use with [Sinatra](http://sinatrarb.com), [Padrino](http://padrinorb.com) and Rails.

If you want to use beanstalk for your job processing, consider using Backburner.
Backburner is heavily inspired by Resque and DelayedJob. Backburner stores all jobs as simple JSON message payloads.
Persistent queues are supported when beanstalkd persistence mode is enabled.

Backburner supports multiple queues, job priorities, delays, and timeouts. In addition,
Backburner has robust support for retrying failed jobs, handling error cases,
custom logging, and extensible plugin hooks.

## Why Backburner?

Backburner is well tested and has a familiar, no-nonsense approach to job processing, but that is of secondary importance.
Let's face it, there are a lot of options for background job processing. [DelayedJob](https://github.com/collectiveidea/delayed_job),
and [Resque](https://github.com/defunkt/resque) are the first that come to mind immediately. So, how do we make sense
of which one to use? And why use Backburner over other alternatives?

The key to understanding the differences lies in understanding the different projects and protocols that power these popular queue
libraries under the hood. Every job queue requires a queue store that jobs are put into and pulled out of.
In the case of Resque, jobs are processed through **Redis**, a persistent key-value store. In the case of DelayedJob, jobs are processed through
**ActiveRecord** and a database such as PostgreSQL.

The work queue underlying these gems tells you infinitely more about the differences than anything else.
Beanstalk is probably the best solution for job queues available today for many reasons.
The real question then is... "Why Beanstalk?".

## Why Beanstalk?

Illya has an excellent blog post
[Scalable Work Queues with Beanstalk](http://www.igvita.com/2010/05/20/scalable-work-queues-with-beanstalk/) and
Adam Wiggins posted [an excellent comparison](http://adam.heroku.com/past/2010/4/24/beanstalk_a_simple_and_fast_queueing_backend/).

You will quickly see that **beanstalkd** is an underrated but incredible project that is extremely well-suited as a job queue.
Significantly better suited for this task than Redis or a database. Beanstalk is a simple,
and a very fast work queue service rolled into a single binary - it is the memcached of work queues.
Originally built to power the backend for the 'Causes' Facebook app, it is a mature and production ready open source project.
[PostRank](http://www.postrank.com) uses beanstalk to reliably process millions of jobs a day.

A single instance of Beanstalk is perfectly capable of handling thousands of jobs a second (or more, depending on your job size)
because it is an in-memory, event-driven system. Powered by libevent under the hood,
it requires zero setup (launch and forget, à la memcached), optional log based persistence, an easily parsed ASCII protocol,
and a rich set of tools for job management that go well beyond a simple FIFO work queue.

Beanstalkd supports the following features out of the box:

| Feature | Description                     |
| ------- | ------------------------------- |
| **Parallelized**    | Supports multiple work queues created on demand. |
| **Reliable**        | Beanstalk’s reserve, work, delete cycle ensures reliable processing. |
| **Scheduling**      | Delay enqueuing jobs by a specified interval to schedule processing later |
| **Fast**            | Processes thousands of jobs per second without breaking a sweat. |
| **Priorities**      | Specify priority so important jobs can be processed quickly. |
| **Persistence**     | Jobs are stored in memory for speed, but logged to disk for safe keeping. |
| **Federation**      | Horizontal scalability provided through federation by the client. |
| **Error Handling**  | Bury any job which causes an error for later debugging and inspection.|

Keep in mind that these features are supported out of the box with beanstalk and require no special code within this gem to support.
In the end, **beanstalk is the ideal job queue** while also being ridiculously easy to install and setup.

## Installation

First, you probably want to [install beanstalkd](http://kr.github.com/beanstalkd/download.html), which powers the job queues.
Depending on your platform, this should be as simple as (for Ubuntu):

    $ sudo apt-get install beanstalkd

Add this line to your application's Gemfile:

    gem 'backburner'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install backburner

## Configuration ##

Backburner is extremely simple to setup. Just configure basic settings for backburner:

```ruby
Backburner.configure do |config|
  config.beanstalk_url    = ["beanstalk://127.0.0.1", "..."]
  config.tube_namespace   = "some.app.production"
  config.on_error         = lambda { |e| puts e }
  config.max_job_retries  = 3 # default 0 retries
  config.retry_delay      = 2 # default 5 seconds
  config.default_priority = 65536
  config.respond_timeout  = 120
  config.default_worker   = Backburner::Workers::Simple
  config.logger           = Logger.new(STDOUT)
  config.primary_queue    = "backburner-jobs"
  config.priority_labels  = { :custom => 50, :useless => 1000 }
  config.reserve_timeout  = nil
end
```

The key options available are:

| Option            | Description                                                          |
| ----------------- | -------------------------------                                      |
| `beanstalk_url`   | Address such as 'beanstalk://127.0.0.1' or an array of addresses.    |
| `tube_namespace`  | Prefix used for all tubes related to this backburner queue.          |
| `on_error`        | Lambda invoked with the error whenever any job in the system fails.  |
| `default_worker`  | Worker class that will be used if no other worker is specified.      |
| `max_job_retries` | Integer defines how many times to retry a job before burying.        |
| `retry_delay`     | Integer defines the base time to wait (in secs) between job retries. |
| `logger`          | Logger recorded to when backburner wants to report info or errors.   |
| `primary_queue`   | Primary queue used for a job when an alternate queue is not given.   |
| `priority_labels` | Hash of named priority definitions for your app.                     |
| `reserve_timeout` | Duration to wait for work from a single server, or nil for forever.  |

## Breaking Changes

Since **v0.4.0**: Jobs used to be placed into default queues based on the name of the class enqueuing i.e NewsletterJob would
be put into a 'newsletter-job' queue. After 0.4.0, all jobs are placed into a primary queue named "my.app.namespace.backburner-jobs"
unless otherwise specified.

## Usage

Backburner allows you to create jobs and place them onto any number of beanstalk tubes, and later pull those jobs off the tubes and
process them asynchronously with a worker.

### Enqueuing Jobs ###

At the core, Backburner is about jobs that can be processed asynchronously. Jobs are simple ruby objects which respond to `perform`.

Job objects are queued as JSON onto a tube to be later processed by a worker. Here's an example:

```ruby
class NewsletterJob
  # required
  def self.perform(email, body)
    NewsletterMailer.deliver_text_to_email(email, body)
  end

  # optional, defaults to 'backburner-jobs' tube
  def self.queue
    "newsletter-sender"
  end

  # optional, defaults to default_priority
  def self.queue_priority
    1000 # most urgent priority is 0
  end

  # optional, defaults to respond_timeout
  def self.queue_respond_timeout
    300 # number of seconds before job times out
  end
end
```

You can include the optional `Backburner::Queue` module so you can easily specify queue settings for this job:

```ruby
class NewsletterJob
  include Backburner::Queue
  queue "newsletter-sender"  # defaults to 'backburner-jobs' tube
  queue_priority 1000 # most urgent priority is 0
  queue_respond_timeout 300 # number of seconds before job times out

  def self.perform(email, body)
    NewsletterMailer.deliver_text_to_email(email, body)
  end
end
```

Jobs can be enqueued with:

```ruby
Backburner.enqueue NewsletterJob, 'foo@admin.com', 'lorem ipsum...'
```

`Backburner.enqueue` accepts first a ruby object that supports `perform` and then a series of parameters
to that object's `perform` method. The queue name used by default is `{namespace}.backburner-jobs`
unless otherwise specified.

### Simple Async Jobs ###

In addition to defining custom jobs, a job can also be enqueued by invoking the `async` method on any object which
includes `Backburner::Performable`. Async enqueuing works for both instance and class methods on any _performable_ object.

```ruby
class User
  include Backburner::Performable
  queue "user-jobs"  # defaults to 'user'
  queue_priority 500 # most urgent priority is 0
  queue_respond_timeout 300 # number of seconds before job times out

  def activate(device_id)
    @device = Device.find(device_id)
    # ...
  end

  def self.reset_password(user_id)
    # ...
  end
end

# Async works for instance methods on a persisted object with an `id`
@user = User.first
@user.async(:ttr => 100, :queue => "activate").activate(@device.id)
# ..and for class methods
User.async(:pri => 100, :delay => 10.seconds).reset_password(@user.id)
```

This automatically enqueues a job for that user record that will run `activate` with the specified argument.
Note that you can set the queue name and queue priority at the class level and
you are also able to pass `pri`, `ttr`, `delay` and `queue` directly as options into `async`.
The queue name used by default is `{namespace}.backburner-jobs` if not otherwise specified.

### Working Jobs

Backburner workers are processes that run forever handling jobs that are reserved from the queue. Starting a worker in ruby code is simple:

```ruby
Backburner.work
```

This will process jobs in all queues but you can also restrict processing to specific queues:

```ruby
Backburner.work('newsletter-sender,push-notifier')
```

The Backburner worker also exists as a rake task:

```ruby
require 'backburner/tasks'
```

so you can run:

```
$ QUEUES=newsletter-sender,push-notifier rake backburner:work
```

You can also run the backburner binary for a convenient worker:

```
bundle exec backburner -q newsletter-sender,push-notifier -d -P /var/run/backburner.pid -l /var/log/backburner.log
```

This will daemonize the worker and store the pid and logs automatically. For Rails and Padrino, the environment should
load automatically. For other cases, use the `-r` flag to specify a file to require.

### Delaying Jobs

In Backburner, jobs can be delayed by specifying the `delay` option whenever you enqueue a job. If you want to schedule a job for an hour from now, simply add that option while enqueuing the standard job:

```ruby
Backburner::Worker.enqueue(NewsletterJob, ['foo@admin.com', 'lorem ipsum...'], :delay => 1.hour)
```

or while you schedule an async method call:

```ruby
User.async(:delay => 1.hour).reset_password(@user.id)
```

Backburner will take care of the rest!

### Persistence

Jobs are persisted to queues as JSON objects. Let's take our `User`
example from above. We'll run the following code to create a job:

``` ruby
User.async.reset_password(@user.id)
```

The following JSON will be put on the `{namespace}.backburner-jobs` queue:

``` javascript
{
    'class': 'User',
    'args': [nil, 'reset_password', 123]
}
```

The first argument is the 'id' of the object in the case of an instance method being async'ed. For example:

```ruby
@device = Device.find(987)
@user = User.find(246)
@user.async.activate(@device.id)
```

would be stored as:

``` javascript
{
    'class': 'User',
    'args': [246, 'activate', 987]
}
```

Since all jobs are persisted in JSON, your jobs must only accept arguments that can be encoded into that format.
This is why our examples use object IDs instead of passing around objects.

### Named Priorities

As of v0.4.0, Backburner has support for named priorities. beanstalkd priorities are numerical but
backburner supports a mapping between a word and a numerical value. The following priorities are
available by default: `high` is 0, `medium` is 100, and `low` is 200.

Priorities can be customized with:

```ruby
Backburner.configure do |config|
  config.priority_labels = { :custom => 50, :useful => 5 }
  # or append to default priorities with
  # config.priority_labels  = Backburner::Configuration::PRIORITY_LABELS.merge(:foo => 5)
end
```

and then these aliases can be used anywhere that a numerical value can:

```ruby
Backburner::Worker.enqueue NewsletterJob, ["foo", "bar"], :pri => :custom
User.async(:pri => :useful, :delay => 10.seconds).reset_password(@user.id)
```

Using named priorities can greatly simplify priority management.

### Processing Strategies

In Backburner, there are several different strategies for processing jobs
which are reflected by multiple worker subclasses.
Custom workers can be [defined fairly easily](https://github.com/nesquena/backburner/wiki/Defining-Workers).
By default, Backburner comes with the following workers built-in:

| Worker | Description                                                                 |
| ------- | -------------------------------                                            |
| `Backburner::Workers::Simple` | Single threaded, no forking worker. Simplest option. |
| `Backburner::Workers::Forking` | Basic forking worker that manages crashes and memory bloat. |
| `Backburner::Workers::ThreadsOnFork` | Forking worker that utilizes threads for concurrent processing. |

You can select the default worker for processing with:

```ruby
Backburner.configure do |config|
  config.default_worker = Backburner::Workers::Forking
end
```

or determine the worker on the fly when invoking `work`:

```ruby
Backburner.work('newsletter-sender', :worker => Backburner::Workers::ThreadsOnFork)
```

or through associated rake tasks with:

```
$ QUEUES=newsletter-sender,push-message THREADS=2 GARBAGE=1000 rake backburner:threads_on_fork:work
```

For more information on the threads_on_fork worker, check out the
[ThreadsOnFork Worker](https://github.com/nesquena/backburner/wiki/ThreadsOnFork-worker) documentation.
Additional workers such as individual `threaded` and `forking` strategies will hopefully be contributed in the future.
If you are interested in helping out, please let us know.

### Default Queues

Workers can be easily restricted to processing only a specific set of queues as shown above. However, if you want a worker to
process **all** queues instead, then you can leave the queue list blank.

When you execute a worker without any queues specified, queues for known job queue class with `include Backburner::Queue` will be processed.
To access the list of known queue classes, you can use:

```ruby
Backburner::Worker.known_queue_classes
# => [NewsletterJob, SomeOtherJob]
```

Dynamic queues created by passing queue options **will not be processed** by a default worker. For this reason, you may want to take control over the default list of
queues processed when none are specified. To do this, you can use the `default_queues` class method:

```ruby
Backburner.default_queues.concat(["foo", "bar"])
```

This will ensure that the _foo_ and _bar_ queues are processed by any default workers. You can also add job queue names with:

```ruby
Backburner.default_queues << NewsletterJob.queue
```

The `default_queues` stores the specific list of queues that should be processed by default by a worker.

### Failures

When a job fails in backburner (usually because an exception was raised), the job will be released
and retried again (with progressive delays in between) until the `max_job_retries` configuration is reached.

```ruby
Backburner.configure do |config|
  config.max_job_retries  = 3 # retry jobs 3 times
  config.retry_delay      = 2 # wait 2 seconds in between retries
end
```

Note the default `max_job_retries` is 0, meaning that by default **jobs are not retried**.
If continued retry attempts fail, the job will be buried and can be 'kicked' later for inspection.

You can also setup a custom error handler for jobs using configure:

```ruby
Backburner.configure do |config|
  config.on_error = lambda { |ex| Airbrake.notify(ex) }
end
```

Now all backburner queue errors will appear on airbrake for deeper inspection.

### Logging

Logging in backburner is rather simple. When a job is run, the log records that. When a job
fails, the log records that. When any exceptions occur during processing, the log records that.

By default, the log will print to standard out. You can customize the log to output to any
standard logger by controlling the configuration option:

```ruby
Backburner.configure do |config|
  config.logger = Logger.new(STDOUT)
end
```

Be sure to check logs whenever things do not seem to be processing.

### Hooks

Backburner is highly extensible and can be tailored to your needs by using various hooks that
can be triggered across the job processing lifecycle.
Often using hooks is much easier then trying to monkey patch the externals.

Check out [HOOKS.md](https://github.com/nesquena/backburner/blob/master/HOOKS.md) for a detailed overview on using hooks.

### Workers in Production

Once you have Backburner setup in your application, starting workers is really easy. Once [beanstalkd](http://kr.github.com/beanstalkd/download.html)
is installed, your best bet is to use the built-in rake task that comes with Backburner. Simply add the task to your Rakefile:

```ruby
# Rakefile
require 'backburner/tasks'
```

and then you can start the rake task with:

```bash
$ rake backburner:work
$ QUEUES=newsletter-sender,push-notifier rake backburner:work
```

The best way to deploy these rake tasks is using a monitoring library. We suggest [God](https://github.com/mojombo/god/)
which watches processes and ensures their stability. A simple God recipe for Backburner can be found in
[examples/god](https://github.com/nesquena/backburner/blob/master/examples/god.rb).

In Backburner, if the beanstalkd connection is temporarily severed, several retries to establish the connection will be attempted.
After several retries, if the connection is still not able to be made, a `Beaneater::NotConnected` exception will be raised.
You can manually catch this exception, and attempt another manual retry using `Backburner::Worker.retry_connection!`.

### Web Front-end

Be sure to check out the Sinatra-powered project [beanstalkd_view](https://github.com/denniskuczynski/beanstalkd_view)
by [denniskuczynski](http://github.com/denniskuczynski) which provides an excellent overview of the tubes and
jobs processed by your beanstalk workers. An excellent addition to your Backburner setup.

## Acknowledgements

 * [Nathan Esquenazi](https://github.com/nesquena) - Project maintainer
 * Kristen Tucker - Coming up with the gem name
 * [Tim Lee](https://github.com/timothy1ee), [Josh Hull](https://github.com/joshbuddy), [Nico Taing](https://github.com/Nico-Taing) - Helping me work through the idea
 * [Miso](http://gomiso.com) - Open-source friendly place to work
 * [Evgeniy Denisov](https://github.com/silentshade) - Multiple fixes and cleanups
 * [Andy Bakun](https://github.com/thwarted) - Fixes to how multiple beanstalkd instances are processed
 * [Renan T. Fernandes](https://github.com/ShadowBelmolve) - Added threads_on_fork worker
 * [Daniel Farrell](https://github.com/danielfarrell) - Added forking worker

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## References

The code in this project has been made in light of a few excellent projects:

 * [DelayedJob](https://github.com/collectiveidea/delayed_job)
 * [Resque](https://github.com/defunkt/resque)
 * [Stalker](https://github.com/han/stalker)

Thanks to these projects for inspiration and certain design and implementation decisions.

## Links

 * Code: `git clone git://github.com/nesquena/backburner.git`
 * Home: <http://github.com/nesquena/backburner>
 * Docs: <http://rdoc.info/github/nesquena/backburner/master/frames>
 * Bugs: <http://github.com/nesquena/backburner/issues>
 * Gems: <http://gemcutter.org/gems/backburner>
