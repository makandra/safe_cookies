module SafeCookies
  module Helpers
  
    KNOWN_COOKIES_DIVIDER = '|'
  
    # Since we have to operate on and modify the actual @headers hash that the
    # application returns, cache the @headers['Set-Cookie'] string so that
    # later on, we still know what the application did set.
    def cache_application_cookies_string
      cookies = @headers['Set-Cookie']
      # Rack 1.1 returns an Array
      cookies = cookies.join("\n") if cookies.is_a?(Array)
    
      if cookies and cookies.length > 0
        @application_cookies_string = cookies
      end
      # else, @application_cookies_string will be `nil`
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

    def set_cookie!(name, value, options)
      options = options.dup
      expire_after = options.delete(:expire_after)

      options[:expires] = Time.now + expire_after if expire_after
      options[:path] = '/' unless options.has_key?(:path) # allow setting path = nil
      options[:value] = value
      options[:secure] = should_be_secure?(name)
      options[:httponly] = should_be_http_only?(name)

      # Rack magic
      Rack::Utils.set_cookie_header!(@headers, name, options)
    end
  
  
    # getters
    
    # returns the request cookies minus ignored cookies
    def request_cookies
      Util.except!(@request.cookies.dup, *@config.ignored_cookies)
    end

    def stored_application_cookie_names
      store_cookie = @request.cookies[STORE_COOKIE_NAME] || ""
      store_cookie.split(KNOWN_COOKIES_DIVIDER)
    end

    def rewritable_request_cookies
      Util.slice(request_cookies, *@config.registered_cookies.keys)
    end

    def known_cookie_names
      known = [STORE_COOKIE_NAME, SECURED_COOKIE_NAME]
      known += stored_application_cookie_names
      known += @config.registered_cookies.keys
    end


    # boolean

    def cookies_have_been_rewritten_before?
      @request.cookies.has_key? SECURED_COOKIE_NAME
    end

    def should_be_secure?(cookie)
      cookie_name = cookie.split('=').first.strip
      ssl? and not @config.insecure_cookie?(cookie_name)
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
      not @config.scriptable_cookie?(cookie_name)
    end  

  end
end
