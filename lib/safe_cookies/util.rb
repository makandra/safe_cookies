class SafeCookies::Util
  class << self
    
    def slice(hash, *allowed_keys)
      sliced_hash = hash.select { |key, _value|
        allowed_keys.include? key
      }

      # Normalize the result of Hash#select
      # (Ruby 1.8 returns an Array, Ruby 1.9 returns a Hash)
      Hash[sliced_hash]
    end
    
    # rejected_keys may be of type String or Regex
    def except!(hash, *rejected_keys)
      hash.delete_if do |key, _value|
        rejected_keys.any? { |rejected| rejected === key }
      end
    end
    
  end
end
