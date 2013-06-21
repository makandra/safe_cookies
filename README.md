# SafeCookies

This Gem brings a Middleware that will make all cookies secure. In detail, it will

* set all new cookies 'HttpOnly', unless specified otherwise
* set all new cookies 'secure', if the request came via HTTPS and not specified otherwise
* rewrite existing cookies, setting both flags as above

## Installation

Add this line to your application's Gemfile:

    gem 'safe_cookies'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install safe_cookies

## Usage

In config/environment.rb:

    config.middleware.use SafeCookies::Middleware,
      :remember_token => 1.year,
      :last_action => 30.days,
      :non_secure => %w[default_language],
      :non_http_only => %w[javascript_data]

This will have the `default_language` cookie not made secure, the `javascript_data` cookie
not made HttpOnly. It will update the `remember_token` with an expiry of one year and the
`last_action` cookie with an expiry of 30 days, making both of them secure and HttpOnly.

## About Rails and Cookies

Cookie syntax example:

    Set-Cookie: cookie1=value; secure,cookie2=value; path=/

Actually, there should be one cookie per Set-Cookie header, but since Rails headers
are implemented as Hash, it is not possible to have several Set-Cookie fields.
