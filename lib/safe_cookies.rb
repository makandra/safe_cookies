# -*- encoding: utf-8 -*-
require "safe_cookies/configuration"
require "safe_cookies/cookie_path_fix"
require "safe_cookies/helpers"
require "safe_cookies/util"
require "safe_cookies/version"
require "rack"

# Naming:
# - application_cookies: cookies received from the application. The 'Set-Cookie' header is a string
# - request_cookies: cookies received from the client. Rack::Request#cookies returns a Hash of { 'name' => 'value' }
# - response_cookies: cookies to be sent to the client
#   (= application_cookies + any cookies set in the middleware)

module SafeCookies

  UnknownCookieError = Class.new(StandardError)
  
  STORE_COOKIE_NAME = '_safe_cookies__known_cookies'
  SECURED_COOKIE_NAME = 'secured_old_cookies'
  HELPER_COOKIES_LIFETIME = 10 * 365 * 24 * 60 * 60 # 10 years

  class Middleware
    
    include CookiePathFix
    include Helpers
    
    COOKIE_NAME_REGEX = /(?=^|\n)[^\n;,=]+/i


    def initialize(app)
      @app = app
      @configuration = SafeCookies.configuration or raise "Don't know what to do without configuration"
    end

    def call(env)
      reset_instance_variables
      
      @request = Rack::Request.new(env)
      ensure_no_unknown_cookies_in_request!

      status, @headers, body = @app.call(env)
      cache_application_cookies_string
      
      enhance_application_cookies!
      store_application_cookie_names
      
      delete_cookies_on_bad_path if fix_cookie_paths?
      rewrite_request_cookies unless cookies_have_been_rewritten_before?

      [ status, @headers, body ]
    end

    private
    
    def reset_instance_variables
      @request, @headers, @application_cookies_string = nil
    end

    def ensure_no_unknown_cookies_in_request!
      request_cookie_names = request_cookies.keys.map(&:to_s)
      unknown_cookie_names = request_cookie_names - known_cookie_names
      
      if unknown_cookie_names.any?
        handle_unknown_cookies(unknown_cookie_names)
      end
    end
    
    # Overwrites @header['Set-Cookie']
    def enhance_application_cookies!
      if @application_cookies_string
        cookies = @application_cookies_string.split("\n")
      
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

    def store_application_cookie_names
      if @application_cookies_string
        application_cookie_names = stored_application_cookie_names + @application_cookies_string.scan(COOKIE_NAME_REGEX)
        application_cookies_string = application_cookie_names.uniq.join(KNOWN_COOKIES_DIVIDER)

        set_cookie!(STORE_COOKIE_NAME, application_cookies_string, :expire_after => HELPER_COOKIES_LIFETIME)
      end
    end
    
    # This method takes all cookies sent with the request and rewrites them,
    # making them both secure and http-only (unless specified otherwise in
    # the configuration).
    # With the SECURED_COOKIE_NAME cookie we remember the exact time that we
    # rewrote the cookies.
    def rewrite_request_cookies
      cookies_to_rewrite = request_cookies || []
      
      # don't rewrite request cookies that the application is setting in the response
      if @application_cookies_string
        application_cookie_names = @application_cookies_string.scan(COOKIE_NAME_REGEX)
        Util.except!(cookies_to_rewrite, *application_cookie_names)
      end
      
      if cookies_to_rewrite.any?
        registered_cookies_in_request.each do |cookie_name, options|
          value = request_cookies[cookie_name]

          set_cookie!(cookie_name, value, options)
        end
      
        formatted_now = Rack::Utils.rfc2822(Time.now.gmtime)
        set_cookie!(SECURED_COOKIE_NAME, formatted_now, :expire_after => HELPER_COOKIES_LIFETIME)
      end
    end
    
    # API method
    def handle_unknown_cookies(cookie_names)
      raise SafeCookies::UnknownCookieError.new("Request for '#{@request.url}' had unknown cookies: #{cookie_names.join(', ')}")
    end

  end
end
