# Backburner

Backburner is a beanstalkd-powered job queue designed to be as simple and easy to use as possible.
You can create background jobs, place those on specialized queues and process them later.

Processing background jobs reliably has never been easier. Backburner works with any ruby-based
web framework but is particularly designed for use with Sinatra and [Padrino](http://padrinorb.com).

If you want to use beanstalk for job processing, consider using Backburner. Backburner is heavily inspired by Resque and DelayedJob.
Backburner can be a persistent queue if the beanstalk persistence mode is enabled, supports priority, delays, and timeouts.
Backburner stores jobs as simple JSON payloads.

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

Unfortunately, when you execute a worker without queues specified any job tubes that have not yet been
created **will not be processed** by the worker. For this reason, you may want to take control over the default list of
queues processed when none are specified. To do this, you can use the `default_queues` class method:

```ruby
Backburner.default_queues.concat(["foo", "bar"])
```

You can also add particular job classes to the queue:

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

## Why Backburner?

To be filled in. DelayedJob, Resque, Stalker, et al.

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
 * [Stalker](https://github.com/han/stalker)