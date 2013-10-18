# encoding: utf-8
require 'spec_helper'

describe SafeCookies::Middleware do
  
  it 'does not allow registered cookies to be altered' do
    SafeCookies.configure do |config|
      config.register_cookie('filter', :expire_after => 3600)
    end
    
    filter_options = SafeCookies.configuration.registered_cookies['filter']
    expect { filter_options[:foo] = 'bar' }.to raise_error(Exception, /can't modify frozen hash/i)
  end
  
  describe '.configure' do

    it 'currently does not support the :domain cookie option' do
      registration_with_domain = lambda do
        SafeCookies.configure do |config|
          config.register_cookie('filter', :domain => 'example.com', :expire_after => 3600)
        end
      end
      
      expect(&registration_with_domain).to raise_error(NotImplementedError)
    end
    
    describe 'register_cookie' do
      
      it 'raises an error if a cookie is registered without passing its expiry' do
        registration_without_expiry = lambda do
          SafeCookies.configure do |config|
            config.register_cookie('filter', :some => :option)
          end
        end
        
        expect(&registration_without_expiry).to raise_error(SafeCookies::MissingOptionError)
      end
      
      it 'raises an error if the cookie name is not a String, because the middleware’s logic depends on strings' do
        registration_as_symbol = lambda do
          SafeCookies.configure do |config|
            config.register_cookie(:filter, :some => :option)
          end
        end
        
        expect(&registration_as_symbol).to raise_error(RuntimeError, /must be a string/i)
      end
      
      it 'allows nil as expiry (means session cookie)' do
        registration_with_nil_expiry = lambda do
          SafeCookies.configure do |config|
            config.register_cookie('filter', :expire_after => nil)
          end
        end
        
        expect(&registration_with_nil_expiry).to_not raise_error(SafeCookies::MissingOptionError)
      end 
     
    end
    
  end

end
