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
  config.tube_namespace = "myblog.production"
end
```

At the core, echelon is about jobs to process. Jobs are simple ruby objects with a method called process. Any object which responds to `process` can be queued as a job. Job objects are queued as JSON to be later processed by a task runner.

```ruby
class NewsletterJob < Echelon::Job
  name "newsletter"

  def initialize(args)
    @body, @customer = args['body'], args['customer']
  end

  def perform
    emails.each { |e| NewsletterMailer.deliver_text_to_email(text, e) }
  end
end
```

Jobs can then be enqueued using 

    Echelon::Worker.enqueue NewsletterJob, { :body => 'lorem ipsum...', :customer => Customer.first }

### Methods as Jobs ###

In addition to defining custom jobs, a job can also be enqueued by invoking the `delay` method on any object.

```ruby
# without echelon
@user.activate!(@device)

# with echelon
@user.delay.activate!(@device)
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