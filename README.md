# SafeCookies

This gem has a middleware that will make all cookies secure. In detail, it will
to two separate things:

1) set all new application cookies 'HttpOnly', unless specified otherwise;  
   set all new application cookies 'secure', if the request came via HTTPS and not specified otherwise

2) rewrite request cookies, setting both flags as above

## Installation

#### Step 1
Add `gem 'safe_cookies'` to your application's Gemfile, then run `bundle install`.

#### Step 2
**Rails 3 and 4**: add the following lines to the application block in config/application.rb:

    require 'safe_cookies'
    config.middleware.insert_before ActionDispatch::Cookies, SafeCookies::Middleware

**Rails 2:** add the following lines to the initializer block in config/environment.rb:

    require 'safe_cookies'
    config.middleware.insert_before ActionController::Session::CookieStore, SafeCookies::Middleware

#### Step 3
Add a configuration block either just below the lines you added in step 2 or in
an initializer (e.g. `config/initializers/safe_cookies.rb`).

#### Done!

Now all your cookies will be made `secure` and `HttpOnly`. But what if you need
a cookie to be accessible via HTTP or Javascript?


### Having a cookie non-secure or non-HttpOnly
Tell the middleware which cookies not to make `secure` or `HttpOnly` by
registering them. The `:expire_after` option is required.

    SafeCookies.configure do |config|
      config.register_cookie 'default_language', :expire_after => 10.years, :secure => false
      config.register_cookie 'javascript_data', :expire_after => 1.day, :http_only => false
    end

### Employing SafeCookies in apps that are already running in production
Unfortunately, [the client won't ever tell us](http://tools.ietf.org/html/rfc6265#section-4.2.2)
if it stores the cookie with flags such as `secure` or which expiry date it
currently has. Therefore, in order to make the middleware retroactively secure
cookies owned by the client, you need to register each of those cookies with
the middleware, specifying their properties.

Carefully scan your app for cookies you are using. There's no easy way to find
out if you missed one (but see below for some help the gem provides).

    SafeCookies.configure do |config|
      config.register_cookie 'remember_token', :expire_after => 1.year
      config.register_cookie 'last_action', :expire_after => 30.days, :path => '/commerce'
    end

Available options are: `:expire_after` (required)`, :path, :secure, :http_only`.


## Dealing with unknown cookies

There are lots of cookies your application receives that you never did set.
However, if you want to know about any unknown cookies touching your
application, SafeCookies offers two ways to achieve this.

1) If you set `config.log_unknown_cookies = true` in the configuration, all
unknown cookies will be written to the Rails log. When you start implementing
the middleware, closely watch it to find cookies you forgot to register.

2) You may overwrite `SafeCookies::Middleware#handle_unknown_cookies(cookies)`
in the config initializer for customized behaviour (like, notifying you per
email).


## Ignoring cookies

The middleware won't see request cookies that are configured to be ignored. Use this to keep your logs lean, if you are using the `log_unknown_cookies` option.

You can tell the middleware to ignore cookies with the `config.ignore_cookie`
directive, which takes either a String or a Regex parameter. Be careful when using regular expressions!


## Fix cookie paths

In August 2013 we noticed a bug in SafeCookies < 0.1.4, by which secured cookies would be set for the
current "directory" (see comments in `cookie_path_fix.rb`) instead of root (which usually is what you want).
Users would get multiple cookies for that domain, leading to issues like being unable to sign in.

The configuration option `config.fix_paths` turns on fixing this error. It requires an option
`:for_cookies_secured_before => Time.parse('some minutes after you will have deployed')` which reflects the
point of time from which cookies will be secured with the correct path. The middleware will fix the cookie
paths by rewriting all cookies that it has already secured, but only if they were secured before the time
you specified.


## Development

- Tests live in `spec`.
- You can run specs from the project root by saying `bundle exec rake`.

If you would like to contribute:

- Fork the repository.
- Push your changes **with passing specs**.
- Send us a pull request.
