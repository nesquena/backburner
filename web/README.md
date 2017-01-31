# Backburner Web Monitoring Interface

This is a Backbone Marionnette application built with Grunt.js using Bower as the Javascript dependency manager.

## Including the web interface in a Rails application

``` ruby
require 'backburner/web'

Example::Application.routes.draw do

  mount Backburner::Web, at: '/backburner'
end
```

## Building the JS and CSS Resources

To build the JS and CSS resources:

First ensure that npm, grunt, and bower are installed:
* https://npmjs.org/
* https://npmjs.org/package/grunt
* https://npmjs.org/package/bower

Then:

1. cd backburner/web
2. npm install
3. bower install
4. grunt

This will output minified JS and concatenated CSS files into the backburner/web/dist directory.

## Backburner API

This web interface leverages JSON API calls defined in the backburner/lib/backburner/web.rb Sinatra application.