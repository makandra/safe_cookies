require 'spec_helper'

describe SafeCookies::Util do
  
  describe '.except!' do
    
    before do
      @hash = { 'a' => 1, 'ab' => 2, 'b' => 3 }
    end

    it 'deletes the given keys from the original hash' do
      SafeCookies::Util.except!(@hash, 'a')
      @hash.should == { 'ab' => 2, 'b' => 3 }
    end
    
    it 'deletes all keys that match the regex' do
      SafeCookies::Util.except!(@hash, /b/)
      @hash.should == { 'a' => 1 }
    end
    
    it 'returns the original hash' do
      SafeCookies::Util.except!(@hash, /(?!)/).should == @hash
    end
    
  end

end