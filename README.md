# Echelon

Processing background jobs reliably has never been easier. Echelon is a beanstalkd-powered messaging job queue designed
to be as simple and easy to use as possible. Defining jobs is intuitive and familiar. Echelon works with any ruby-based
web framework but is particularly designed for use with Sinatra and [Padrino](http://padrinorb.com).

If you want to use beanstalk for job processing, consider using echelon.

## Installation

Add this line to your application's Gemfile:

    gem 'echelon'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install echelon

## Usage

### Configuration ###

Echelon is extremely simple to use. First, configure basic settings for echelon:

```ruby
Echelon.configure do |config|
  config.beanstalk_url = "beanstalk://127.0.0.1"
  config.tube_namespace = "some.app.production"
  config.on_error = lambda { |e| puts e }
  config.default_priority = 65536
  config.respond_timeout = 120
end
```

### Enqueuing Jobs ###

At the core, echelon is about jobs to process. Jobs are simple ruby objects with a method called perform.
Any object which responds to `process` can be queued as a job. Job objects are queued as JSON to be later processed by a task runner.

```ruby
class NewsletterJob
  include Echelon::Job
  queue "newsletter"

  def self.perform(email, body)
    NewsletterMailer.deliver_text_to_email(email, body)
  end
end
```

Jobs can then be enqueued using:

```ruby
Echelon::Worker.enqueue NewsletterJob, 'lorem ipsum...', 5
```

### Simpler Async Jobs ###

In addition to defining custom jobs, a job can also be enqueued by invoking the `delay` method on any object which includes `Echelon::Performable`.

```ruby
class User
  include Echelon::Performable

  def activate(device_id)
    @device = Device.find(device_id)
    # ...
  end
end

@user = User.first
@user.async(:pri => 1000, :ttr => 100).activate(@device.id)
```

This will automatically enqueue a job that will run `activate` with the specified argument for that user record. Note you are able to pass
`pri`, `ttr`, `delay` and `queue` directly as options into `async`

### Working Jobs

Echelon workers are processes that run forever handling jobs that get reserved. Starting a worker in ruby code is simple:

```ruby
Echelon.work!
```

This will process jobs in all queues but you can also restrict to only specific jobs:

```ruby
Echelon.work!('newsletter_sender')
```

Echelon worker exists as a rake task:

```ruby
require 'echelon/tasks'
```

and then you can run:

```
$ TUBES=newsletter_sender,push_message rake echelon:work
```

You can also use the echelon daemon for a convenient daemonized process:

```
bundle exec echelon newsletter\_sender,push_message -d -P /var/run/echelon.pid -l /var/log/echelon.log
```

This will daemonize a worker and store the pid and logs automatically.

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