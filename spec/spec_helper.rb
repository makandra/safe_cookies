require File.expand_path('../../lib/safe_cookies', __FILE__)
require 'timecop'

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
  
  config.before(:each) { SafeCookies.configure {} }
  config.after(:each) {
    SafeCookies.configuration = nil
    Timecop.return
  }
end

def stub_app_call(app, options = {})
  env = {}
  env['Set-Cookie'] = options[:application_cookies] if options[:application_cookies]
  app.stub :call => [ stub, env, stub ]
end

def set_request_cookies(env, *cookies)
  env['HTTP_COOKIE'] = cookies.join(',')
end

def extract_cookies(set_cookies_header)
  set_cookies_header.scan(/(?=^|\n)[^\n;]+=[^\n;]+(?=;\s)/i)
end
