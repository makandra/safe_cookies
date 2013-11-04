module SafeCookies
  module CookiePathFix
  
    # Previously, the SafeCookies gem would not set a path when rewriting
    # cookies. Browsers then would assume and store the current "directory"
    # (see below), leading to multiple cookies per domain.
    #
    # If the cookies were secured before the configured datetime, this method
    # instructs the client to delete all cookies it sent with the request + the
    # SECURED_COOKIE_NAME helper cookie.
    # The middleware still sees the request cookies and will rewrite them as
    # if it hadn't seen them before, setting them on the correct path (root,
    # per default).
    def delete_cookies_on_bad_path
      rewritable_request_cookies = Util.slice(request_cookies, *rewritable_cookie_names)
      rewritable_request_cookies.keys.each &method(:delete_cookie_for_current_directory)
      delete_cookie_for_current_directory(SafeCookies::SECURED_COOKIE_NAME)
    
      # Delete this cookie here, so the middleware believes it hasn't secured
      # the cookies yet.
      @request.cookies.delete(SafeCookies::SECURED_COOKIE_NAME)
    end
      
    private
  
    def fix_cookie_paths?
      @configuration.fix_cookie_paths or return false
    
      cookies_need_path_fix = (secured_old_cookies_timestamp < @configuration.correct_cookie_paths_timestamp)

      cookies_have_been_rewritten_before? and cookies_need_path_fix
    end

    # Delete cookies by giving them an expiry in the past,
    # cf. https://tools.ietf.org/html/rfc6265#section-4.1.2.
    #
    # Most important, as specified in
    # https://tools.ietf.org/html/rfc6265#section-4.1.2.4 and in section 5.1.4,
    # cookies set without a path will be set for the current "directory", that is:
    #
    #   > ... the characters of the uri-path from the first character up
    #   > to, but not including, the right-most %x2F ("/").
    #
    # However, Firefox includes the right-most slash when guessing the cookie path,
    # so we must resort to letting browsers estimate the deletion cookie path again.
    def delete_cookie_for_current_directory(cookie_name)
      unless current_directory_is_root?
        one_week = (7 * 24 * 60 * 60)
        set_cookie!(cookie_name, "", :path => nil, :expire_after => -one_week)
      end
    end
  
    def current_directory_is_root?
      # in words: "there are not three slashes before any query params"
      !@request.path[%r(^/[^/]+/[^\?]+), 0]
    end
  
    def secured_old_cookies_timestamp
      Time.rfc2822(request_cookies[SafeCookies::SECURED_COOKIE_NAME])
    rescue ArgumentError
      # If we cannot parse the secured_old_cookies time,
      # assume it was before we noticed the bug to ensure
      # broken cookie paths will be fixed.
      Time.parse "2013-08-25 0:00"
    end

  end
end
