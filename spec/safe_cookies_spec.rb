# -*- encoding: utf-8 -*-
require 'spec_helper'

# Explanation:
# app#call(env) is how the middleware calls the app
#   returns the app's response
# subject#call(env) is how the middleware is called "from below"
#   returns the response that is passed through the web server to the client

describe SafeCookies::Middleware do
  
  let(:app) { stub 'application' }
  let(:env) { { 'HTTPS' => 'on' } }
  subject { described_class.new(app) }
 
  it 'should rewrite specified existing cookies as "secure" and "HttpOnly", but only once' do
    Timecop.freeze do
      # first request: rewrite cookie
      subject = described_class.new(app, :foo => 24 * 60 * 60)
      app.should_receive(:call).and_return([ stub, {}, stub ])
      env['HTTP_COOKIE'] = 'foo=bar'
    
      code, headers, response = subject.call(env)
      expected_expiry = Rack::Utils.rfc2822((Time.now + 24 * 60 * 60).gmtime) # a special date format needed here
      headers['Set-Cookie'].should =~ /foo=bar;[^\n]* HttpOnly/
      headers['Set-Cookie'].should =~ /foo=bar;[^\n]* secure/
      headers['Set-Cookie'].should =~ /expires=#{expected_expiry}/
      headers['Set-Cookie'].should =~ /secured_old_cookies=/ # the indication cookie
      
      # second request: do not rewrite cookie again
      subject = described_class.new(app, :foo => 24 * 60 * 60)
      app.should_receive(:call).and_return([ stub, {}, stub ])
      received_cookies = headers['Set-Cookie'].scan(/[^\n;]+=[^\n;]+(?=;\s)/i) # extract cookies
      env['HTTP_COOKIE'] = received_cookies.join(',')

      code, headers, response = subject.call(env)
      headers['Set-Cookie'].to_s.should == ""
    end
  end
  
  it "should make new cookies secure" do
    app.should_receive(:call).and_return([ stub, { 'Set-Cookie' => 'neuer_cookie=neuer_cookie_wert'}, stub ])
    
    code, headers, response = subject.call(env)
    headers['Set-Cookie'].should =~ /neuer_cookie=neuer_cookie_wert;.* secure/
  end
  
  it "should make new cookies http_only" do
    app.should_receive(:call).and_return([ stub, { 'Set-Cookie' => 'neuer_cookie=neuer_cookie_wert'}, stub ])
    
    code, headers, response = subject.call(env)
    headers['Set-Cookie'].should =~ /neuer_cookie=neuer_cookie_wert;.* HttpOnly/
  end
  
  it "should not make new cookies secure that are specified as 'non_secure'" do
    subject = described_class.new(app, :non_secure => %w[filter-settings])
    app.should_receive(:call).and_return([ stub, { 'Set-Cookie' => 'filter-settings=sort_by_date'}, stub ])
    
    code, headers, response = subject.call(env)
    headers['Set-Cookie'].should include("filter-settings=sort_by_date")
    headers['Set-Cookie'].should_not match(/secure/i)
  end
  
  it "should not make new cookies http_only that are specified as 'non_http_only'" do
    subject = described_class.new(app, :non_http_only => %w[javascript-cookie])
    app.should_receive(:call).and_return([ stub, { 'Set-Cookie' => 'javascript-cookie=xss'}, stub ])
    
    code, headers, response = subject.call(env)
    headers['Set-Cookie'].should include("javascript-cookie=xss")
    headers['Set-Cookie'].should_not match(/HttpOnly/i)
  end
  
  it "should prefer the application's cookie if both client and app are sending one" do
    app.should_receive(:call).and_return([ stub, { 'Set-Cookie' => 'cookie=überschrieben'}, stub ])
    env['HTTP_COOKIE'] = 'cookie=wert'
    
    code, headers, response = subject.call(env)
    headers['Set-Cookie'].should include("cookie=überschrieben")
  end

  it "should not make existing cookies secure that are specified as 'non_secure'" do
    subject = described_class.new(app, :filter => 24 * 60 * 60, :non_secure => %w[filter])
    app.should_receive(:call).and_return([ stub, {}, stub ])
    env['HTTP_COOKIE'] = 'filter=cars_only'
    
    code, headers, response = subject.call(env)
    set_cookie = headers['Set-Cookie'].gsub(/,(?=\s\d)/, '') # remove commas in expiry dates to simplify matching below
    set_cookie.should =~ /filter=cars_only;.* HttpOnly/
    set_cookie.should_not match(/filter=cars_only;.* secure/)
  end
  
  it "should not make existing cookies http_only that are specified as 'non_http_only'" do
    subject = described_class.new(app, :js_data => 24 * 60 * 60, :non_http_only => %w[js_data])
    app.should_receive(:call).and_return([ stub, {}, stub ])
    env['HTTP_COOKIE'] = 'js_data=json'
    
    code, headers, response = subject.call(env)
    set_cookie = headers['Set-Cookie']
    set_cookie.should =~ /js_data=json;.* secure/
    set_cookie.should_not match(/js_data=json;.* HttpOnly/)
  end
  
  it "should not make cookies secure if the request was not secure" do
    subject = described_class.new(app)
    app.should_receive(:call).and_return([ stub, { 'Set-Cookie' => 'filter-settings=sort_by_date'}, stub ])
    env['HTTPS'] = 'off'
    
    code, headers, response = subject.call(env)
    headers['Set-Cookie'].should include("filter-settings=sort_by_date")
    headers['Set-Cookie'].should_not match(/secure/i)
  end

end
