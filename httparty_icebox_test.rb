require 'rubygems'
require 'fakeweb'
require 'ftools'
require 'test/unit'
require 'shoulda'

require 'httparty'
require 'httparty_icebox'

FakeWeb.register_uri :get, "http://example.com/",
                     [ {:body => "Hello, World!"},  {:body => "Goodbye, World!"} ]

FakeWeb.register_uri :get, "http://example.com/?name=Joshua",
                     [ {:body => "Hello, Joshua!"}, {:body => "Goodbye, Joshua!"} ]

FakeWeb.register_uri :get, "http://example.com/teapot",
                     { :body => "I'm a teapot", :status => 200, :'x-powered-by'=>"Teapot 1.0" }

FakeWeb.register_uri :get,  "http://example.com/bad",  {:body => "Not Found", :status => 404}
FakeWeb.register_uri :post, "http://example.com/form", {:body => "Processed", :status => 200}

class HTTPartyIceboxTest < Test::Unit::TestCase

  context "When Icebox is included in a class, it" do

    setup do
      MyResource.class_eval do
        @cache = nil
        cache :store => 'memory', :timeout => 0.1#, :logger => Logger.new(STDOUT)
        # cache :store => 'file', :timeout => 0.1, :location => File.dirname(__FILE__), :logger => Logger.new(STDOUT)
      end
    end

    should "allow setting cache" do
      assert_respond_to MyResource, :cache
    end

    should "set the cache" do
      MyResource.cache :store => 'memory', :timeout => 5, :logger => nil
      assert_not_nil MyResource.cache
      assert_not_nil MyResource.cache.store
      assert_instance_of HTTParty::Icebox::Store::MemoryStore, MyResource.cache.store
    end

    should "get the response from network and cache it" do
      MyResource.get('http://example.com')
      assert_not_nil MyResource.cache.get('http://example.com')
    end

    should "get the cached response when the cache still fresh" do
      MyResource.get('http://example.com')
      assert_equal 'Hello, World!', MyResource.get('http://example.com').body
    end

    should "get the fresh response when the cache is stale" do
      MyResource.get('http://example.com')
      sleep 0.3
      assert_equal 'Goodbye, World!', MyResource.get('http://example.com').body
    end

    should "include the query params in key" do
      MyResource.get('http://example.com/?name=Joshua')
      assert_equal 'Hello, Joshua!', MyResource.get('http://example.com/?name=Joshua').body
    end

    should "not cache the response when receiving error from network" do
      MyResource.get('http://example.com/bad')
      assert_nil MyResource.cache.get('http://example.com/bad')
    end

    should "not cache the response when not a GET request" do
      MyResource.post('http://example.com/form')
      assert_nil MyResource.cache.get('http://example.com/form')
    end

    should "store reponse with code, body and headers" do
      MyResource.get('http://example.com/teapot')
      cached = MyResource.get('http://example.com/teapot')
      assert_equal 200, cached.code
      assert_equal "I'm a teapot", cached.body
      assert_not_nil cached.headers['x-powered-by']
      assert_not_nil cached.headers['x-powered-by'].first
      assert_equal 'Teapot 1.0', cached.headers['x-powered-by'].first
    end

  end

  # ---------------------------------------------------------------------------

  context "A logger for Icebox" do

    setup do
      HTTParty::Icebox::Cache.class_eval { @logger = nil }
      @logpath = Pathname(__FILE__).dirname.expand_path.join('test.log').to_s
    end

    should "return default logger" do
      assert_instance_of Logger, HTTParty::Icebox::Cache.default_logger
    end

    should "return default logger when none was set" do
      assert_instance_of Logger, HTTParty::Icebox::Cache.logger
    end

    should "set be set to nil when given nil" do
      HTTParty::Icebox::Cache.logger=(nil)
      assert_instance_of Logger, HTTParty::Icebox::Cache.logger
      HTTParty::Icebox::Cache.logger.info "Hi" # Should not see this
      assert_equal nil, # UH :/
                   HTTParty::Icebox::Cache.logger.instance_variable_get(:@logdev).instance_eval{defined?(@filename)}
    end

    should "should set logger to a Logger instance" do
      HTTParty::Icebox::Cache.logger = ::Logger.new(STDOUT)
      assert_instance_of Logger, HTTParty::Icebox::Cache.logger
    end

    should "create a logger to log to file" do
      HTTParty::Icebox::Cache.logger = @logpath
      assert_equal @logpath, # UH :/
                   HTTParty::Icebox::Cache.logger.instance_variable_get(:@logdev).instance_variable_get(:@filename)
      FileUtils.rm_rf(@logpath)
    end

  end

  # ---------------------------------------------------------------------------

  context "When looking up store, it" do

    should "use default store" do
      # 'memory' is default
      assert_equal HTTParty::Icebox::Store::MemoryStore, HTTParty::Icebox::Cache.lookup_store('memory')
    end

    should "find existing store" do
      assert_equal HTTParty::Icebox::Store::FileStore, HTTParty::Icebox::Cache.lookup_store('file')
    end

    should "raise when passed non-existing store" do
      assert_raise(HTTParty::Icebox::Store::StoreNotFound) { HTTParty::Icebox::Cache.lookup_store('ether') }
    end
  end

  # ---------------------------------------------------------------------------

  context "AbstractStore class" do

    should "raise unless passed :timeout option" do
      assert_raise(ArgumentError) { HTTParty::Icebox::Store::AbstractStore.new( :timeout => nil ) }
    end

    should "raise when abstract methods are called" do
      s = HTTParty::Icebox::Store::AbstractStore.new( :timeout => 1, :logger => nil )
      assert_raise(NoMethodError) { s.set }
    end
  end

  # ---------------------------------------------------------------------------

  context "Memory cache" do
    setup do
      @cache = HTTParty::Icebox::Cache.new('memory', :timeout => 0.1, :logger => nil)
      @key   = 'abc'
      @value = { :one => [1, 2, 3], :two => 'Hello', :three => 1...5 }
      @cache.set @key, @value
    end

    should "store and retrieve the value" do
      assert_equal @value, @cache.get('abc')
    end

    should "miss when retrieving the value after timeout" do
      sleep 0.1
      assert_nil @cache.get('abc')
    end
  end

  # ---------------------------------------------------------------------------

  context "File store cache" do
    setup do
      @cache = HTTParty::Icebox::Cache.new('file', :timeout => 1)
      @key   = 'abc'
      @value = { :one => [1, 2, 3], :two => 'Hello', :three => 1...5 }
      @cache.set @key, @value
    end

    should "store and retrieve the value" do
      assert_equal @value, @cache.get('abc')
    end

    should "miss when retrieving the value after timeout" do
      sleep 1.1
      assert_nil @cache.get('abc')
    end
  end

  # ---------------------------------------------------------------------------


end

# Fake Resource to mixin the functionality into
class MyResource
  include HTTParty
  include HTTParty::Icebox
  cache :store => 'memory', :timeout => 0.2
end
