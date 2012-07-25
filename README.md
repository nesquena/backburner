# Echelon

Processing background jobs reliably has never been easier. Echelon is a beanstalkd-powered messaging job queue designed
to be as simple and easy to use as possible. Defining jobs is intuitive and familiar. Echelon works with any ruby-based
web framework but is particularly designed for use with Sinatra and [Padrino](http://padrinorb.com).

If you have been using beanstalk for job processing, consider moving to echelon.

## Installation

Add this line to your application's Gemfile:

    gem 'echelon'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install echelon

## Usage

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

Jobs can then be enqueued using

```ruby
Echelon::Worker.enqueue NewsletterJob, 'lorem ipsum...', 5
```

### Methods as Jobs ###

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
@user.async(:pri => 1000, :ttr => 1000).activate(@device.id)
```

### Workers

Echelon workers are processes that run forever. They basically do:

```ruby
They basically do this:

``` ruby
start
loop do
  if job = reserve
    job.process
  else
    sleep 5 # Polling frequency = 5
  end
end
shutdown
```

Starting a worker in ruby code is simple:

```ruby
Echelon.work!
```

This will process jobs in all queues, you can also restrict to only specific jobs:

```ruby
Echelon.work!('newsletter_sender')
```

Echelon exists as a rake task as well as a binary daemon:

```ruby
require 'echelon/tasks'
```

and then you can run:

```
$ TUBES=newsletter_sender,push_message rake echelon:work
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## References

Used a few other excellent projects as references:

 * [DelayedJob](https://github.com/collectiveidea/delayed_job)
 * [DJ AR Backend](https://github.com/collectiveidea/delayed_job_active_record/tree/master/lib/delayed/backend)
 * [Stalker](https://github.com/han/stalker)