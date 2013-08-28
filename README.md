# SafeCookies

This Gem brings a middleware that will make all cookies secure. In detail, it will:

* set all new application cookies 'HttpOnly', unless specified otherwise
* set all new application cookies 'secure', if the request came via HTTPS and not specified otherwise
* rewrite request cookies, setting both flags as above

## Installation

Add this line to your application's Gemfile:

    gem 'safe_cookies'

Then run:

    $ bundle

Or install it yourself as:

    $ gem install safe_cookies


## Usage

### Step 1
**Rails 3**: add the following line in config/application.rb:

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

### Step 2
Register cookies, either just after the lines you added in step 1 or in in an initializer
(e.g. config/initializers/safe_cookies.rb):

    SafeCookies.configure do |config|
      config.register_cookie :remember_token, :expire_after => 1.year
      config.register_cookie :last_action, :expire_after => 30.days
      config.register_cookie :default_language, :expire_after => 10.years, :secure => false
      config.register_cookie :javascript_data, :expire_after => 1.day, :http_only => false
    end

This will have the `default_language` cookie not made secure, the `javascript_data` cookie
not made http-only. It will rewrite the `remember_token` with an expiry of one year and the
`last_action` cookie with an expiry of 30 days, making both of them secure and http-only.
Available options are: `:expire_after (required), :path, :secure, :http_only`.

### Step 3
Override `SafeCookies::Middleware#handle_unknown_cookies(cookies)` (see "Dealing with unregistered cookies" below).


## Dealing with unregistered cookies

The middleware is not able to secure cookies without knowing their properties (most important: their
expiry). Unfortunately, the [client won't ever tell us](http://tools.ietf.org/html/rfc6265#section-4.2.2)
if the cookie was originally sent with flags such as "secure" or which expiry date it currently has.
Therefore, it is important to register all cookies that users may come with, specifying their properties.
Unregistered cookies cannot be secured.

If a request brings a cookie that is not registered, the middleware will raise
`SafeCookies::UnknownCookieError`. Rails 3+ should handle the exception as any other in your application,
but by default, **you will not be notified from Rails 2 applications** and the user will see a standard
500 Server Error. Override `SafeCookies::Middleware#handle_unknown_cookies(cookies)` in the config
initializer for customized exception handling (like, notifying you per email).

You should not ignore an unregistered cookie, but instead register it.


## Fix cookie paths

In August 2013 we noticed a bug in SafeCookies < 0.1.4, by which secured cookies would be set for the
current "directory" (see comments in `cookie_path_fix.rb`) instead of root (which usually is what you want).
Users would get multiple cookies for that domain, leading to issues like being unable to sign in.

The configuration option `config.fix_paths` turns on fixing this error. It requires an option
`:for_cookies_secured_before => Time.parse('some minutes after you will have deployed')` which reflects the
point of time from which cookies will be secured with the correct path. The middleware will fix the cookie
paths by rewriting all cookies that it has already secured, but only if the were secured before the time
you specified.
