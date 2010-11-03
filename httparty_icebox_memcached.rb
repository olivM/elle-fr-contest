#
# Assumes that MEMCACHE is instantiated, using the gem, use the following lines in environment.rb:
#
# require 'memcached'
# MEMCACHE = Memcached.new("localhost:11211")
#
# Usage:
#
#   require 'httparty'
#   require 'httparty_icebox'
#   require 'httparty_icebox_memcached'
#   
#   class Foo
#     include HTTParty
#     include HTTParty::Icebox
#     cache :store => 'memcached', :timeout => 3600*1 # cached 1 hour
#   end
#
#

require 'httparty_icebox'

include HTTParty::Icebox::Store

class MemcachedStore < AbstractStore
  include HTTParty::Icebox
  
  def initialize(options={})
    super;self
  end
  def set(key, value)
    res = MEMCACHE.set(key, value, @timeout)
    #puts "MemcachedStore.set, key: #{key}, result: #{res}"
    Cache.logger.info("Cache: set (#{key})")
    true
  end
  def get(key)
    data = MEMCACHE.get(key) rescue nil
    Cache.logger.info("Cache: #{data.nil? ? "miss" : "hit"} (#{key})")
    data
  end
  def exists?(key)
    data = MEMCACHE.get(key) rescue nil
    !data.nil?
  end
  def stale?(key)
    return true unless exists?(key)
  end
end
