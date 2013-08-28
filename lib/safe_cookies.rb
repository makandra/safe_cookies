# -*- encoding: utf-8 -*-
require "safe_cookies/configuration"
require "safe_cookies/cookie_path_fix"
require "safe_cookies/util"
require "safe_cookies/version"
require "rack"

module SafeCookies

  UnknownCookieError = Class.new(StandardError)
  
  CACHE_COOKIE_NAME = '_safe_cookies__known_cookies'
  SECURED_COOKIE_NAME = 'secured_old_cookies'
  HELPER_COOKIES_LIFETIME = 10 * 365 * 24 * 60 * 60 # 10 years

  class Middleware
    
    include CookiePathFix
    
    KNOWN_COOKIES_DIVIDER = '|'


    def initialize(app)
      @app = app
      @configuration = SafeCookies.configuration or raise "Don't know what to do without configuration"
    end

    def call(env)
      reset_instance_variables
      
      @request = Rack::Request.new(env)
      ensure_no_unknown_cookies!

      status, @headers, body = @app.call(env)

      fix_cookie_paths if fix_cookie_paths?
      rewrite_request_cookies unless cookies_have_been_rewritten_before
      cache_application_cookies
      rewrite_application_cookies

      [ status, @headers, body ]
    end

    private
    
    def reset_instance_variables
      @request, @headers = nil
    end

    def secure(cookie)
      # Regexp from https://github.com/tobmatth/rack-ssl-enforcer/
      if should_be_secure?(cookie) and cookie !~ /(^|;\s)secure($|;)/
        "#{cookie}; secure"
      else
        cookie
      end
    end

    def http_only(cookie)
      if should_be_http_only?(cookie) and cookie !~ /(^|;\s)HttpOnly($|;)/
        "#{cookie}; HttpOnly"
      else
        cookie
      end
    end
    
    # This method takes all cookies sent with the request and rewrites them,
    # making them both secure and http-only (unless specified otherwise in
    # the configuration).
    # With the SECURED_COOKIE_NAME cookie we remember the exact time that we
    # rewrote the cookies.
    def rewrite_request_cookies
      if @request.cookies.any?
        registered_cookies_in_request.each do |registered_cookie, options|
          value = @request.cookies[registered_cookie]

          set_cookie!(registered_cookie, value, options)
        end
      
        formatted_now = Rack::Utils.rfc2822(Time.now.gmtime)
        set_cookie!(SECURED_COOKIE_NAME, formatted_now, :expire_after => HELPER_COOKIES_LIFETIME)
      end
    end

    def set_cookie!(name, value, options)
      options = options.dup
      expire_after = options.delete(:expire_after)

      options[:expires] = Time.now + expire_after if expire_after
      options[:path] = '/' unless options.has_key?(:path) # allow setting path = nil
      options[:value] = value
      options[:secure] = should_be_secure?(name)
      options[:httponly] = should_be_http_only?(name)

      Rack::Utils.set_cookie_header!(@headers, name, options)
    end

    def rewrite_application_cookies
      cookies = @headers['Set-Cookie']
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
        @headers['Set-Cookie'] = cookies.join("\n")
      end
    end
    
    def should_be_secure?(cookie)
      cookie_name = cookie.split('=').first.strip
      ssl? and not @configuration.insecure_cookie?(cookie_name)
    end
    
    def ssl?
      if @request.respond_to?(:ssl?)
        @request.ssl?
      else
        # older Rack versions
        @request.scheme == 'https'
      end
    end
    
    def should_be_http_only?(cookie)
      cookie_name = cookie.split('=').first.strip
      not @configuration.scriptable_cookie?(cookie_name)
    end
    
    def ensure_no_unknown_cookies!
      request_cookies = @request.cookies.keys.map(&:to_s)
      unknown_cookies = request_cookies - known_cookies
      
      if unknown_cookies.any?
        handle_unknown_cookies(unknown_cookies)
      end
    end
    
    def handle_unknown_cookies(cookies)
      raise SafeCookies::UnknownCookieError.new("Request for '#{@request.url}' had unknown cookies: #{cookies.join(', ')}")
    end
    
    def cache_application_cookies
      new_application_cookies = @headers['Set-Cookie']
      
      if new_application_cookies
        new_application_cookies = new_application_cookies.join("\n") if new_application_cookies.is_a?(Array)
        application_cookies = cached_application_cookies + new_application_cookies.scan(/(?=^|\n)[^\n;,=]+/i)
        application_cookies_string = application_cookies.uniq.join(KNOWN_COOKIES_DIVIDER)
        
        set_cookie!(CACHE_COOKIE_NAME, application_cookies_string, :expire_after => HELPER_COOKIES_LIFETIME)
      end
    end
    
    def cached_application_cookies
      cache_cookie = @request.cookies[CACHE_COOKIE_NAME] || ""
      cache_cookie.split(KNOWN_COOKIES_DIVIDER)
    end
    
    def known_cookies
      known = [CACHE_COOKIE_NAME, SECURED_COOKIE_NAME]
      known += cached_application_cookies
      known += @configuration.registered_cookies.keys
    end
    
    def cookies_have_been_rewritten_before
      @request.cookies.has_key? SECURED_COOKIE_NAME
    end
    
    # returns those of the registered cookies that appear in the request
    def registered_cookies_in_request
      Util.slice(@configuration.registered_cookies, *@request.cookies.keys)
    end

  end
end
