# This gem is no longer maintained!

Read about [reasons and alternatives](https://makandracards.com/makandra/53693-rails-making-all-cookies-secure-to-pass-a-security-audit).


--------------------

# SafeCookies

This gem has a middleware that will make all cookies secure, by setting the
`HttpOnly` and the `secure` flag for all cookies the application sets on the
client.

Making a cookie `HttpOnly` prevents Javascripts from seeing it, which really
should be the default. It makes it way harder to steal cookie information via
malicious Javascript.

Making a cookie `secure` tells the browser to only send the cookie over HTTPS
connections, protecting it from being sniffed by a man-in-the-middle. (Setting a
[HSTS](http://en.wikipedia.org/wiki/HTTP_Strict_Transport_Security) header
achieves the same, but Safari < 7 and IE < 11 don't speak HSTS.)

SafeCookies will *additionally* rewrite all cookies the user is sending. **But**
it can only do so, if the cookie was registered before (see below). It will rewrite
user cookies only once per user.


## Installation

1. Add `gem 'safe_cookies'` to your application's Gemfile, then run `bundle install`.

2. Add a configuration block in an initializer (e.g. `config/initializers/safe_cookies.rb`):

        SafeCookies.configure do |config|
          # configuration ...
        end

3. Register the middleware:

    Rails 3+: add the following lines to the application block in `config/application.rb`:

        require 'safe_cookies'
        config.middleware.insert_before ActionDispatch::Cookies, SafeCookies::Middleware

    Rails 2: add the following lines to the initializer block in `config/environment.rb`:

        require 'safe_cookies'
        config.middleware.insert_before ActionController::Session::CookieStore, SafeCookies::Middleware

Now all new cookies will be made `secure` and `HttpOnly`. But what about cookies
already out there?


## Updating existing cookies

Unfortunately, [the client won't ever tell us](http://tools.ietf.org/html/rfc6265#section-4.2.2)
if it stores a cookie with flags such as `secure` or which expiry date it is
stored with. Therefore, in order to make the middleware retroactively secure
cookies owned by the client, you need to register each of those cookies with
the middleware, specifying their properties.

Carefully scan your app for cookies you are using. There's no easy way to find
out if you missed one (but see below for some help the gem provides).

    SafeCookies.configure do |config|
      config.register_cookie 'remember_token', :expire_after => 1.year
      config.register_cookie 'last_action', :expire_after => 30.days, :path => '/commerce'
    end

Available options are: `:expire_after` (required)`, :path, :secure, :http_only`.
For cookies with "session" expiry, set `:expire_after => nil`.


## Having a cookie non-secure or non-HttpOnly

Tell SafeCookies which cookies not to make `secure` or `HttpOnly` by registering
them, just like above:

    SafeCookies.configure do |config|
      config.register_cookie 'default_language', :expire_after => 10.years, :secure => false
      config.register_cookie 'javascript_data', :expire_after => 1.day, :http_only => false
    end


## Finding unregistered user cookies

There are lots of cookies your application receives that you never did set.
However, if you want to know about any unknown cookies touching your
application, SafeCookies gives you two tools.

1) If you set `config.log_unknown_cookies = true` in the configuration block, all
unknown cookies will be written to the Rails log. When you start implementing
the middleware, closely watch it to find cookies you forgot to register.

2) You may overwrite `SafeCookies::Middleware#handle_unknown_cookies(cookies)`
in the configuration block for customized behaviour (like, notifying you per
email).

To ignore cookies that are irrelevant to you, you may configure them to be
ignored. Use the `config.ignore_cookie` directive, which takes either a String
or a Regex parameter. *Be careful when using regular expressions!*


## Fixing cookie paths

In August 2013 we noticed a bug in SafeCookies < 0.1.4, by which secured cookies
would be set for the current "directory" (see comments in `cookie_path_fix.rb`)
instead of root (which usually is what you want). Users would get multiple
cookies for that domain, leading to issues like being unable to sign in.

The configuration option `config.fix_paths` turns on fixing this error. It
expects an option `:for_cookies_secured_before => Time.parse('some minutes after
you will have deployed')` which reflects the point of time from which SafeCookies
can expect cookies to be set with the correct path. It will only rewrite cookies
with a new path if it had set them before that point of time.


## Development

- Tests live in `spec`.
- You can run specs from the project root by saying `bundle exec rake`.

If you would like to contribute:

- Fork the repository.
- Push your changes **with passing specs**.
- Send us a pull request.
