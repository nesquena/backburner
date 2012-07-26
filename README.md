# Backburner

Backburner is a [beanstalkd](http://kr.github.com/beanstalkd/)-powered job queue designed to with an easy and familiar DSL.
You can create background jobs, place those on specialized queues and then process them later.

Processing background jobs reliably has never been easier then with beanstalkd and Backburner. This gem works with any ruby-based
web framework but is well-suited for use with [Sinatra](http://sinatrarb.com), [Padrino](http://padrinorb.com) and Rails.

If you want to use beanstalk for job processing, consider using Backburner. Backburner is heavily inspired by Resque and DelayedJob.
Backburner can be a persistent queue if the beanstalk persistence mode is enabled, supports priority, delays, and timeouts.
Backburner stores all jobs as simple JSON message payloads.

## Why Backburner?

Let's face it; there are a lot of options for background job processing. [DelayedJob](https://github.com/collectiveidea/delayed_job),
and [Resque](https://github.com/defunkt/resque) are the first that come to mind immediately. So, how do we make sense
of which one to use? And why use Backburner over other alternatives?

The key to understanding the differences lies in understanding the different projects and protocols that underlie these popular queue
libraries. Every job queue requires a queue store that jobs are put into and popped out of. In the case of Resque, jobs are processed
through **Redis**, a persistent key-value store. In the case of DelayedJob, jobs are processed through 
ActiveRecord and a database such as PostgreSQL.

Backburner is well tested and has a familiar, no-nonsense approach to handling job processing but that is of secondary importance.
The data store chosen used to power a job queue tell you far more about the different queue solutions. \
Beanstalk is very likely the best solution for job queues available today in any number of aspects detailed below. 
The real question then is... "Why Beanstalk?".

## Why Beanstalk?

Illya has an excellent blog post 
[Scalable Work Queues with Beanstalk](http://www.igvita.com/2010/05/20/scalable-work-queues-with-beanstalk/) and
Adam Wiggins posted [an excellent comparison](http://adam.heroku.com/past/2010/4/24/beanstalk_a_simple_and_fast_queueing_backend/).

You will quickly see that **beanstalkd** is an underrated but incredible project that is extremely well-suited as a job queue. 
Significantly better suited for this task then Redis or a database. Beanstalk is a simple, 
and a very fast work queue service rolled into a single binary - it is the memcached of work queues. 
Originally built to power the backend for the 'Causes' Facebook app, it is a mature and production ready open source project. 
[PostRank](http://www.postrank.com) uses beanstalk to reliably process millions of jobs a day.

A single instance of Beanstalk is perfectly capable of handling thousands of jobs a second (or more, depending on your job size) 
because it is an in-memory, event-driven system. Powered by libevent under the hood, 
it requires zero setup (launch and forget, ala memcached), optional log based persistence, an easily parsed ASCII protocol, 
and a rich set of tools for job management that go well beyond a simple FIFO work queue.

Beanstalk supports the following features natively, out of the box, without any questions asked:

 * Priorities - Specify a higher priority and jobs will jump ahead to be processed first.
 * Persistence - Although jobs are stored in memory for speed and simplicity (ala memcached), 
   the state is easily persisted to disk so you won't lose jobs.
 * Federation - Fault-tolerance and horizontal scalability is provided the same way as Memcache - through federation by the client.
 * Buried jobs - When a job causes an error, you can bury it. This keeps it around for later debugging while keeping it separated from active jobs.
 * Reliable - Beanstalk’s reserve, work, delete cycle, with a timeout to dereserve the job, means it’s near impossible for a bad client lose a job.
 * Parallel Queues - Supports multiple 'tubes' (work queues), which are created and deleted on demand.
 * Really Fast - Beanstalkd is **much** [faster then alternatives](http://adam.heroku.com/past/2010/4/24/beanstalk_a_simple_and_fast_queueing_backend).

Keep in mind that these features are supported out of the box with beanstalk and require no special code within this gem to support. 
In the end, **beanstalk is the ideal job queue** while also being ridiculously easy to install and setup.

## Installation

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
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = "some.app.production"
  config.on_error = lambda { |e| puts e }
  config.default_priority = 65536
  config.respond_timeout = 120
end
```

## Usage

Backburner allows you to create jobs and place them on a beanstalk queue, and later pull those jobs off the queue and
process them asynchronously.

### Enqueuing Jobs ###

At the core, Backburner is about jobs that can be processed. Jobs are simple ruby objects with a method defined named `perform`.

Any object which responds to `perform` can be queued as a job. Job objects are queued as JSON to be later processed by a task runner.
Here's an example:

```ruby
class NewsletterJob
  include Backburner::Queue
  queue "newsletter"

  def self.perform(email, body)
    NewsletterMailer.deliver_text_to_email(email, body)
  end
end
```

Notice that you must include the `Backburner::Queue` module and that you can set a `queue` name within the job automatically.
Jobs can then be enqueued using:

```ruby
Backburner.enqueue NewsletterJob, 'lorem ipsum...', 5
```

`Backburner.enqueue` accepts first a ruby object that supports `perform` and then a series of parameters
to that object's `perform` method. The queue name used by default is the normalized class name (i.e `{namespace}.newsletter-job`)
if not otherwise specified.

### Simple Async Jobs ###

In addition to defining custom jobs, a job can also be enqueued by invoking the `async` method on any object which
includes `Backburner::Performable`.

```ruby
class User
  include Backburner::Performable

  def activate(device_id)
    @device = Device.find(device_id)
    # ...
  end
end

@user = User.first
@user.async(:pri => 1000, :ttr => 100, :queue => "user.activate").activate(@device.id)
```

This will automatically enqueue a job that will run `activate` with the specified argument for that user record.
The queue name used by default is the normalized class name (i.e `{namespace}.user`) if not otherwise specified.
Note you are able to pass `pri`, `ttr`, `delay` and `queue` directly as options into `async`.

### Working Jobs

Backburner workers are processes that run forever handling jobs that get reserved. Starting a worker in ruby code is simple:

```ruby
Backburner.work
```

This will process jobs in all queues but you can also restrict processing to specific queues:

```ruby
Backburner.work('newsletter_sender')
```

The Backburner worker also exists as a rake task:

```ruby
require 'backburner/tasks'
```

so you can run:

```
$ QUEUES=newsletter-sender,push-message rake backburner:work
```

You can also run the backburner binary for a convenient worker:

```
bundle exec backburner newsletter-sender,push-message -d -P /var/run/backburner.pid -l /var/log/backburner.log
```

This will daemonize the worker and store the pid and logs automatically.

### Default Queues

Workers can be easily restricted to processing only a specific set of queues as shown above. However, if you want a worker to
process **all** queues instead, then you can leave the queue list blank.

When you execute a worker without queues specified, any queue for a known job queue class with `include Backburner::Queue` will be processed. To access the list of known
queue classes, you can use:

```ruby
Backburner::Worker.known_queue_classes
# => [NewsletterJob, SomeOtherJob]
```

Dynamic queues created by passing queue options **will not be processed** by a default worker. For this reason, you may want to take control over the default list of
queues processed when none are specified. To do this, you can use the `default_queues` class method:

```ruby
Backburner.default_queues.concat(["foo", "bar"])
```

This will ensure that the _foo_ and _bar_ queues are processed by default. You can also add job queue names:

```ruby
Backburner.default_queues << NewsletterJob.queue
```

The `default_queues` stores the specific list of queues that should be processed by default by a worker.

### Failures

You can setup the error handler for jobs using configure:

```ruby
Backburner.configure do |config|
  config.on_error = lambda { |ex| Airbrake.notify(ex) }
end
```

Now all beanstalk queue errors will show up on airbrake.
If a job fails in beanstalk, the job is automatically buried and must be 'kicked' later.

### Logging

Right now, all logging happens to standard out and can be piped to a file or any other output manually. More on logging coming later.

### Front-end Monitoring

To be completed is an admin dashboard that provides insight into beanstalk jobs via a simple Sinatra front-end. Coming soon.

## Acknowledgements

 * Nathan Esquenazi - Project maintainer
 * Kristen Tucker - Coming up with the gem name
 * [Tim Lee](https://github.com/timothy1ee), [Josh Hull](https://github.com/joshbuddy), [Nico Taing](https://github.com/Nico-Taing) - Helping me work through the idea
 * [Miso](http://gomiso.com) - Open-source friendly place to work

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## References

The code in this project has been adapted from a few excellent projects:

 * [DelayedJob](https://github.com/collectiveidea/delayed_job)
 * [Resque](https://github.com/defunkt/resque)
 * [Stalker](https://github.com/han/stalker)