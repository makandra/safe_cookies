require 'spec_helper'
require 'cgi'

describe SafeCookies::Middleware do
  
  describe 'cookie path fix' do
    
    subject { described_class.new(app) }
    let(:app) { stub 'application' }
    let(:env) { { 'HTTPS' => 'on' } }
    
    before do
      @now = Time.parse('2050-01-01 00:00')
      Timecop.travel(@now)
    end
    
    def set_default_request_cookies(secured_at = Time.parse('2040-01-01 00:00'))
      set_request_cookies(env, 'cookie_to_update=some_data', "secured_old_cookies=#{CGI::escape(secured_at.gmtime.rfc2822)}")
    end


    context 'rewriting previously secured cookies' do
      
      before do
        SafeCookies.configure do |config|
          config.register_cookie('cookie_to_update', :expire_after => 3600)
          config.fix_paths :for_cookies_secured_before => Time.parse('2050-01-02 00:00')
        end
        
        stub_app_call(app)
        set_default_request_cookies
      end
      
      it 'updates the timestamp on the root secured_old_cookies cookie' do
        code, headers, response = subject.call(env)

        updated_secured_old_cookies_timestamp = 'Fri%2C+31+Dec+2049+23%3A00%3A00+-0000'
        headers['Set-Cookie'].should =~ /secured_old_cookies=#{Regexp.escape updated_secured_old_cookies_timestamp}; path=\/;/
      end
      
      it 'sets the cookie path to "/"' do
        code, headers, response = subject.call(env)
        headers['Set-Cookie'].should =~ /cookie_to_update=some_data;.*path=\/;/
      end
    
      it 'deletes cookies for the current "directory"' do
        env['PATH_INFO'] = '/complex/sub/path'
  
        code, headers, response = subject.call(env)
        set_cookie = headers['Set-Cookie']
      
        # overwrite the cookie with an empty value
        set_cookie.should =~ /cookie_to_update=;/
        
        # the deletion cookie must not have a path, so browsers use their own implementation of cookie path
        # determination, the same they used when the cookie was implicitly set on the wrong path
        set_cookie.should_not =~ %r(cookie_to_update=;.*path=)
        
        # cookies are deleted by giving them an expiry in the past
        deletion_expiry = set_cookie[/cookie_to_update=;.*expires=([^;]+)/, 1]
        Time.parse(deletion_expiry).should < @now
      end
    
      it 'does not delete cookies from root ("/") requests, since root cookies are the default we expect' do
        env['PATH_INFO'] = '/'
      
        code, headers, response = subject.call(env)
        headers['Set-Cookie'].should_not =~ /cookie_to_update=;/
      end
    
      it 'does not delete cookies from first-level paths like "/first_level", since their "directory" is "/"' do
        env['PATH_INFO'] = '/first_level'
      
        code, headers, response = subject.call(env)
        headers['Set-Cookie'].should_not =~ /cookie_to_update=;/
      end
    
      it 'does not delete cookies from first-level paths like "/first_level/", since their "directory" is "/"' do
        env['PATH_INFO'] = '/first_level'
      
        code, headers, response = subject.call(env)
        headers['Set-Cookie'].should_not =~ /cookie_to_update=;/
      end
    
      it 'should not be confused by query parameters' do
        env['PATH_INFO'] = '/some/sub/directory/with?query=params&and=/another/path'
      
        code, headers, response = subject.call(env)
        headers['Set-Cookie'].should =~ %r(cookie_to_update=;)
      end
    
      it 'should not "fix" a path set by the application' do
        stub_app_call(app, :application_cookies => 'new_cookie=NEW_DATA; path=/special/path')
        env['PATH_INFO'] = '/special/path/sub/folder'

        code, headers, response = subject.call(env)
        headers['Set-Cookie'].should =~ %r(new_cookie=NEW_DATA;.*path=/special/path;)
      end
    
      it 'deletes the secured_old_cookies cookie on the current "directory", so future requests to that directory do not trigger a rewrite of all cookies' do
        env['PATH_INFO'] = '/complex/sub/path'
      
        code, headers, response = subject.call(env)
  
        # delete the "directory" secured_old_cookies cookie ...
        headers['Set-Cookie'].should =~ %r(secured_old_cookies=;)
        # ... but do not delete the root secured_old_cookies cookie
        headers['Set-Cookie'].should =~ %r(secured_old_cookies=\w+.*path=/;)
      end
      
      context 'unparseable secured_old_cookies timestamp,' do
        
        before do
          set_request_cookies(env, 'cookie_to_update=some_data', 'secured_old_cookies=rubbish')
          code, @headers, response = subject.call(env)
        end
        
        it 'rewrites cookies anyway' do
          @headers['Set-Cookie'].should include('cookie_to_update=some_data;')
        end
        
        it 'sets a new, parseable secured_old_cookies timestamp' do
          @headers['Set-Cookie'].should include("secured_old_cookies=#{CGI::escape @now.gmtime.rfc2822}")
        end

      end

    end
    
    it 'does not rewrite previously secured cookies if not told so' do
      SafeCookies.configure do |config|
        config.register_cookie('cookie_to_update', :expire_after => 3600)
        # missing config.fix_paths
      end
      stub_app_call(app)
      set_default_request_cookies

      code, headers, response = subject.call(env)
      headers['Set-Cookie'].should be_nil
    end
    
    it 'raises an error if told to fix cookie paths without specifying a date' do
      fix_paths_without_timestamp = lambda do
        SafeCookies.configure do |config|
          config.fix_paths # missing :for_cookies_secured_before option
        end
      end

      expect(&fix_paths_without_timestamp).to raise_error(SafeCookies::MissingOptionError)
    end
  
    it 'does not rewrite cookies that were secured after the correct_cookie_paths_timestamp' do
      SafeCookies.configure do |config|
        config.register_cookie('cookie_to_update', :expire_after => 3600)
        config.fix_paths :for_cookies_secured_before => Time.parse('2050-01-02 00:00')
      end
      stub_app_call(app)
      set_default_request_cookies(Time.parse('2050-01-03 00:00'))

      code, headers, response = subject.call(env)
      headers['Set-Cookie'].should be_nil
    end
    
  end
  
end