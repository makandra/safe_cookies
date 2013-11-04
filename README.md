# SafeCookies

This Gem has a middleware that will make all cookies secure. In detail, it will:

* set all new application cookies 'HttpOnly', unless specified otherwise
* set all new application cookies 'secure', if the request came via HTTPS and not specified otherwise
* rewrite request cookies, setting both flags as above

## Installation

### Step 1
Add this line to your application's Gemfile:

    gem 'safe_cookies'

Then run `bundle install`.

Though this gem is aimed at Rails applications, you may even use it without
Rails. In that case, install it with `gem install safe_cookies`.


### Step 2
**Rails 3 and 4**: add the following line in config/application.rb:

    class Application < Rails::Application
      # ...
      config.middleware.insert_before ActionDispatch::Cookies, SafeCookies::Middleware
    end

**Rails 2:** add the following lines in config/environment.rb:

    Rails::Initializer.run do |config|
      # ...
      require 'safe_cookies'
      config.middleware.insert_before ActionController::Session::CookieStore, SafeCookies::Middleware
    end

### Step 3
Register cookies, either just after the lines you added above or in in an initializer
(e.g. in `config/initializers/safe_cookies.rb`):

    SafeCookies.configure do |config|
      config.register_cookie :remember_token, :expire_after => 1.year
      config.register_cookie :last_action, :expire_after => 30.days
      config.register_cookie :default_language, :expire_after => 10.years, :secure => false
      config.register_cookie :javascript_data, :expire_after => 1.day, :http_only => false
    end

If a request has any of those four cookies, the middleware will set them anew. The `remember_token` and
`last_action` cookies will be made `secure` and `HttpOnly`.
Since we want to access the default language even if the user comes via HTTP,  the `default_language`
cookie is not made secure. Analogous, the `javascript_data` cookie will be used by a script and hence is
not made `HttpOnly`.

Available options are: `:expire_after (required), :path, :secure, :http_only`.

### Step 4 (important for Rails 2 only)
Override `SafeCookies::Middleware#handle_unknown_cookies(cookies)` to notify you
e.g. by email (see "Dealing with unregistered cookies" below).


## Dealing with unregistered cookies

The middleware is not able to secure cookies without knowing their attributes
(most importantly: their expiry). Unfortunately, [the client won't ever tell us](http://tools.ietf.org/html/rfc6265#section-4.2.2)
if it stores the cookie with flags such as "secure" or which expiry date it
currently has. Therefore, it is important to register all cookies that may be
sent by the client, specifying their properties. Unregistered cookies cannot be
secured.

If a request contains a cookie that is not registered, the middleware will raise
a `SafeCookies::UnknownCookieError`. Rails 3+ should handle the exception as any
other in your application, but by default, **you will not be notified from Rails
2 applications** and the user will see a standard 500 Server Error. Override
`SafeCookies::Middleware#handle_unknown_cookies(cookies)` in the config
initializer for customized exception handling (like, notifying you per email).

You should register any cookie that your application has to do with. However, there are cookies that you
do not control, like Google's `__utma` & co. You can tell the middleware to ignore those with the
`config.ignore_cookie` directive, which takes either a String or a Regex parameter. Be careful when using
regular expressions!


## Fix cookie paths

In August 2013 we noticed a bug in SafeCookies < 0.1.4, by which secured cookies would be set for the
current "directory" (see comments in `cookie_path_fix.rb`) instead of root (which usually is what you want).
Users would get multiple cookies for that domain, leading to issues like being unable to sign in.

The configuration option `config.fix_paths` turns on fixing this error. It requires an option
`:for_cookies_secured_before => Time.parse('some minutes after you will have deployed')` which reflects the
point of time from which cookies will be secured with the correct path. The middleware will fix the cookie
paths by rewriting all cookies that it has already secured, but only if the were secured before the time
you specified.


## Development

- Tests live in `spec`.
- You can run specs from the project root by saying `bundle exec rake`.

If you would like to contribute:

- Fork the repository.
- Push your changes **with passing specs**.
- Send us a pull request.
