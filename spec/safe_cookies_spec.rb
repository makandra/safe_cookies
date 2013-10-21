# -*- encoding: utf-8 -*-
require 'spec_helper'

describe SafeCookies::Middleware do
  
  subject { described_class.new(app) }
  let(:app) { stub 'application' }
  let(:env) { { 'HTTPS' => 'on' } }
  
  it 'should rewrite registered request cookies as secure and http-only, but only once' do
    SafeCookies.configure do |config|
      config.register_cookie('foo', :expire_after => 3600)
    end

    # first request: rewrite cookie
    stub_app_call(app)
    set_request_cookies(env, 'foo=bar')
  
    code, headers, response = subject.call(env)
    headers['Set-Cookie'].should =~ /foo=bar;.* secure; HttpOnly/
    
    # second request: do not rewrite cookie again
    received_cookies = extract_cookies(headers['Set-Cookie'])
    received_cookies.should include('foo=bar') # sanity check
    
    # client returns with the cookies, `app` and `subject` are different
    # objects than in the previous request
    other_app = stub('application')
    other_subject = described_class.new(other_app)
    
    stub_app_call(other_app)
    set_request_cookies(env, *received_cookies)

    code, headers, response = other_subject.call(env)
    headers['Set-Cookie'].to_s.should == ''
  end

  it 'should not make cookies secure if the request was not secure' do
    stub_app_call(app, :application_cookies => 'filter-settings=sort_by_date')
    env['HTTPS'] = 'off'
    
    code, headers, response = subject.call(env)
    headers['Set-Cookie'].should include("filter-settings=sort_by_date")
    headers['Set-Cookie'].should_not match(/\bsecure\b/i)
  end

  it 'expires the secured_old_cookies helper cookie in ten years' do
    Timecop.freeze(Time.parse('2013-09-17 17:53'))

    SafeCookies.configure do |config|
      config.register_cookie('cookie_to_update', :expire_after => 3600)
    end
    
    set_request_cookies(env, 'cookie_to_update=some_data')
    stub_app_call(app)

    code, headers, response = subject.call(env)
    
    headers['Set-Cookie'].should =~ /secured_old_cookies.*expires=Fri, 15 Sep 2023 \d\d:\d\d:\d\d/
  end
  
  context 'cookie attributes' do

    it 'sets cookies on the root path' do
      SafeCookies.configure do |config|
        config.register_cookie('my_old_cookie', :expire_after => 3600)
      end
    
      set_request_cookies(env, 'my_old_cookie=foobar')
      stub_app_call(app)

      code, headers, response = subject.call(env)

      cookies = headers['Set-Cookie'].split("\n")
      cookies.each do |cookie|
        cookie.should include('; path=/;')
      end
    end
  
    it 'should not alter cookie attributes coming from the application' do
      stub_app_call(app, :application_cookies => 'cookie=data; path=/; expires=next_week')
  
      code, headers, response = subject.call(env)
      headers['Set-Cookie'].should =~ %r(cookie=data; path=/; expires=next_week; secure; HttpOnly)
    end
  
    it 'should respect cookie attributes set in the configuration' do
      Timecop.freeze
    
      SafeCookies.configure do |config|
        config.register_cookie('foo', :expire_after => 3600, :path => '/special/path')
      end

      stub_app_call(app)
      set_request_cookies(env, 'foo=bar')
      env['PATH_INFO'] = '/special/path/subfolder'
  
      code, headers, response = subject.call(env)
      expected_expiry = Rack::Utils.rfc2822((Time.now + 3600).gmtime) # a special date format needed here
      headers['Set-Cookie'].should =~ %r(foo=bar; path=/special/path; expires=#{expected_expiry}; secure; HttpOnly)
    end
    
  end
  
  context 'cookies set by the application' do
    
    it 'should make application cookies secure and http-only' do
      stub_app_call(app, :application_cookies => 'application_cookie=value')

      code, headers, response = subject.call(env)
      headers['Set-Cookie'].should =~ /application_cookie=value;.* secure; HttpOnly/
    end
  
    it 'should not make application cookies secure that are specified as non-secure' do
      SafeCookies.configure do |config|
        config.register_cookie('filter-settings', :expire_after => 3600, :secure => false)
      end
    
      stub_app_call(app, :application_cookies => 'filter-settings=sort_by_date')
    
      code, headers, response = subject.call(env)
      headers['Set-Cookie'].should include("filter-settings=sort_by_date")
      headers['Set-Cookie'].should_not =~ /filter-settings=.*secure/i
    end
  
    it 'should not make application cookies http-only that are specified as non-http-only' do
      SafeCookies.configure do |config|
        config.register_cookie('javascript-cookie', :expire_after => 3600, :http_only => false)
      end
      stub_app_call(app, :application_cookies => 'javascript-cookie=xss')
    
      code, headers, response = subject.call(env)
      headers['Set-Cookie'].should include("javascript-cookie=xss")
      headers['Set-Cookie'].should_not =~ /javascript-cookie=.*HttpOnly/i
    end
  
    it 'does not rewrite a client cookie when the application is setting a cookie with the same name' do
      SafeCookies.configure do |config|
        config.register_cookie('cookie', :expire_after => 3600)
      end

      stub_app_call(app, :application_cookies => 'cookie=from_application')
      set_request_cookies(env, 'cookie=from_client')
    
      code, headers, response = subject.call(env)

      headers['Set-Cookie'].should include("cookie=from_application")
      headers['Set-Cookie'].should_not include("cookie=from_client")
    end

  end
  
  context 'cookies sent by the client' do
    
    it 'should not make request cookies secure that are specified as non-secure' do
      SafeCookies.configure do |config|
        config.register_cookie('filter', :expire_after => 3600, :secure => false)
      end
    
      stub_app_call(app)
      set_request_cookies(env, 'filter=cars_only')
    
      code, headers, response = subject.call(env)
      headers['Set-Cookie'].should =~ /filter=cars_only;.* HttpOnly/
      headers['Set-Cookie'].should_not =~ /filter=cars_only;.* secure/
    end
  
    it 'should not make request cookies http-only that are specified as non-http-only' do
      SafeCookies.configure do |config|
        config.register_cookie('js-data', :expire_after => 3600, :http_only => false)
      end
    
      stub_app_call(app)
      set_request_cookies(env, 'js-data=json')
    
      code, headers, response = subject.call(env)
      headers['Set-Cookie'].should =~ /js-data=json;.* secure/
      headers['Set-Cookie'].should_not =~ /js-data=json;.* HttpOnly/
    end
    
  end

  context 'ignored cookies' do
    
    before do
      stub_app_call(app)
      set_request_cookies(env, '__utma=123', '__utmz=456')
    end

    it 'does not rewrite ignored cookies given as string' do
      SafeCookies.configure do |config|
        config.ignore_cookie '__utma'
        config.ignore_cookie '__utmz'
      end

      code, headers, response = subject.call(env)
      headers['Set-Cookie'].should_not =~ /__utm/
    end

    it 'does not rewrite ignored cookies given as regex' do
      SafeCookies.configure do |config|
        config.ignore_cookie /^__utm/
      end
      
      code, headers, response = subject.call(env)
      headers['Set-Cookie'].should_not =~ /__utm/
    end
    
  end

  context 'unknown request cookies' do
    
    it 'should raise an error if there is an unknown cookie' do
      set_request_cookies(env, 'foo=bar')
    
      expect{ subject.call(env) }.to raise_error(SafeCookies::UnknownCookieError)
    end
    
    it 'should not raise an error if the (unregistered) cookie was initially set by the application' do
      # application sets cookie
      stub_app_call(app, :application_cookies => 'foo=bar; path=/some/path; secure')
      
      code, headers, response = subject.call(env)

      received_cookies = extract_cookies(headers['Set-Cookie'])
      received_cookies.should include('foo=bar') # sanity check
      
      # client returns with the cookie, `app` and `subject` are different
      # objects than in the previous request
      other_app = stub('application')
      other_subject = described_class.new(other_app)
      
      stub_app_call(other_app)
      set_request_cookies(env, *received_cookies)

      other_subject.call(env)
    end
    
    it 'should not raise an error if the cookie is listed in the cookie configuration' do
      SafeCookies.configure do |config|
        config.register_cookie('foo', :expire_after => 3600)
      end
    
      stub_app_call(app)
      set_request_cookies(env, 'foo=bar')
      
      subject.call(env)
    end
    
    it 'does not raise an error if the cookie is ignored' do
      SafeCookies.configure do |config|
        config.ignore_cookie '__utma'
      end

      stub_app_call(app)
      set_request_cookies(env, '__utma=tracking')
      
      subject.call(env)
    end
    
    it 'allows overwriting the error mechanism' do
      stub_app_call(app)
      set_request_cookies(env, 'foo=bar')
      
      def subject.handle_unknown_cookies(*args)
        @custom_method_called = true
      end
      
      subject.call(env)
      subject.instance_variable_get('@custom_method_called').should == true
    end
    
  end

end
