# -*- encoding: utf-8 -*-
require "safe_cookies/version"
require "rack"

module SafeCookies
  class Middleware


    def initialize(app, options = {})
      # Pass a hash for `cookies_to_update` with name as key and lifetime as value.
      # Use this to update existing cookies that you expect to receive.
      #
      # Unfortunately, the client won't ever tell us if the cookie was originally
      # sent with flags such as "secure" or which expiry date it currently has:
      # http://tools.ietf.org/html/rfc6265#section-4.2.2
      #
      # The :non_secure option specifies cookies that will not be made secure. Use
      # this for storing site usage settings like filters etc. that need to be available
      # when not on HTTPS (this should rarely be the case).
      #
      # The :non_http_only option is analog, use it for storing data you want to access
      # with javascript.

      @app = app
      @non_secure = (options.delete(:non_secure) || []).map(&:to_s)
      @non_http_only = (options.delete(:non_http_only) || []).map(&:to_s)
      @cookies_to_update = options
    end

    def call(env)
      @env = env
      status, headers, body = @app.call(@env)

      secure_old_cookies!(headers) if @cookies_to_update.any?
      secure_new_cookies!(headers)

      [ status, headers, body ]
    end

    private

    def secure(cookie)
      # Regexp from https://github.com/tobmatth/rack-ssl-enforcer/
      if secure?(cookie) and cookie !~ /(^|;\s)secure($|;)/
        "#{cookie}; secure"
      else
        cookie
      end
    end

    def http_only(cookie)
      if http_only?(cookie) and cookie !~ /(^|;\s)HttpOnly($|;)/
        "#{cookie}; HttpOnly"
      else
        cookie
      end
    end

    def secure_old_cookies!(headers)
      request = Rack::Request.new(@env)
      return if request.cookies['secured_old_cookies']

      @cookies_to_update.each do |key, expiry|
        key = key.to_s
        if request.cookies.has_key?(key)
          value = request.cookies[key]
          set_secure_cookie!(headers, key, value, expiry)
        end
      end
      set_secure_cookie!(headers, 'secured_old_cookies', Rack::Utils.rfc2822(Time.now.gmtime))
    end

    def set_secure_cookie!(headers, key, value, expire_after = 365 * 24 * 60 * 60) # one year
      options = {
        :value => value,
        :secure => secure?(key),
        :httponly => http_only?(key),
        :expires => Time.now + expire_after # This is what Rails does
      }
      Rack::Utils.set_cookie_header!(headers, key, options)
    end

    def secure_new_cookies!(headers)
      cookies = headers['Set-Cookie']
      if cookies
        # Rails 2.3 / Rack 1.1 offers an array which is actually nice.
        cookies = cookies.split("\n") unless cookies.is_a?(Array)

        # On Rack 1.1, cookie values sometimes contain trailing newlines.
        # Example => ["foo=1; path=/\n", "bar=2; path=/"]
        # Note that they also mess up browsers, when this array is merged
        # again and the "Set-Cookie" header then contains double newlines.
        cookies = cookies.
          map(&:strip).
          select{ |c| c.length > 0}.
          map(&method(:secure)).
          map(&method(:http_only))

        # Unfortunately there is no pretty way to touch a "Set-Cookie" header.
        # It contains more information than the "HTTP_COOKIE" header from the
        # browser's request contained, so a `Rack::Request` can't parse it for
        # us. A `Rack::Response` doesn't offer a way either.
        headers['Set-Cookie'] = cookies.join("\n")
      end
    end
    
    def secure?(cookie)
      name = cookie.split('=').first.strip
      ssl_request? and not @non_secure.include?(name)
    end
    
    def http_only?(cookie)
      name = cookie.split('=').first.strip
      not @non_http_only.include?(name)
    end
    
    def ssl_request?
      @env['HTTPS'] == 'on' || @env['HTTP_X_FORWARDED_PROTO'] == 'https' # this is how Rails does it
    end

  end
end
