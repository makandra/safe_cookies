module SafeCookies
  class Util
    class << self
      
      def slice(hash, *allowed_keys)
        sliced_hash = hash.select { |key, value|
          allowed_keys.include? key
        }

        # Normalize the result of Hash#select
        # (Ruby 1.8 returns an Array, Ruby 1.9 returns a Hash)
        Hash[sliced_hash]
      end
      
    end
  end
end