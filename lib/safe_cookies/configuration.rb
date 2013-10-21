module SafeCookies
  
  MissingOptionError = Class.new(StandardError)

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end

  end

  class Configuration
    attr_reader :registered_cookies, :fix_cookie_paths, :correct_cookie_paths_timestamp, :ignored_cookies

    def initialize
      self.registered_cookies = {}
      self.insecure_cookies = []
      self.scriptable_cookies = []
      self.ignored_cookies = []
    end
    
    # Register cookies you expect to receive. The middleware will rewrite all
    # registered cookies it receives, making them both secure and http_only.
    #
    # Unfortunately, the client won't ever tell us if the cookie was originally
    # sent with flags such as "secure" or which expiry date it currently has:
    # http://tools.ietf.org/html/rfc6265#section-4.2.2
    #
    # Therefore, specify an expiry, and more options if needed:
    #
    #   :expire_after => 1.year
    #   :secure => false
    #   :http_only = false
    #   :path => '/foo/path'
    #
    def register_cookie(name, options)
      name.is_a?(String) or raise "Cookie name must be a String"
      options.has_key?(:expire_after) or raise MissingOptionError.new("Cookie #{name.inspect} was registered without an expiry")
      raise NotImplementedError if options.has_key?(:domain)
      
      registered_cookies[name] = (options || {}).freeze
      insecure_cookies << name if options[:secure] == false
      scriptable_cookies << name if options[:http_only] == false
    end
    
    # Ignore cookies that you don't control like this:
    #
    #   ignore_cookie 'ignored_cookie'
    #   ignore_cookie /^__utm/
    def ignore_cookie(name_or_regex)
      self.ignored_cookies << name_or_regex
    end
    
    def fix_paths(options = {})
      options.has_key?(:for_cookies_secured_before) or raise MissingOptionError.new("Was told to fix paths without the :for_cookies_secured_before timestamp.")

      self.fix_cookie_paths = true
      self.correct_cookie_paths_timestamp = options[:for_cookies_secured_before]
    end
    
    def insecure_cookie?(name)
      insecure_cookies.include? name
    end
    
    def scriptable_cookie?(name)
      scriptable_cookies.include? name
    end
    
    private
    
    attr_accessor :insecure_cookies, :scriptable_cookies
    attr_writer :registered_cookies, :fix_cookie_paths, :correct_cookie_paths_timestamp, :ignored_cookies

  end

end