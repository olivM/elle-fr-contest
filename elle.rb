require 'rubygems'
require 'httparty'
require 'httparty_icebox'

class Elle
  include HTTParty
  include HTTParty::Icebox
  cache :store => 'file', :timeout => 60, :location => '/tmp/cache'
  #cache :store => 'memory', :timeout => 600
  base_uri 'www.elle.fr'
  default_params :output => 'json'
  format :json
  
  #  http://www.elle.fr/elle/ajaxext/GPBlogsVoteGet
  
  def self.get_classement
    get('/elle/ajaxext/GPBlogsVoteGet').parsed_response.sort {|a,b| b['votes'].to_i <=> a['votes'].to_i }
  end

  def self.classement
    idx = 0
    self.get_classement.slice(0,10).collect { |b| "#{idx = idx + 1}. ##{b['blog_id']} - #{b['votes']} votes" }.join("\n")
  end
  
  def self.test
    get('/elle/ajaxext/GPBlogsVoteGet').parsed_response.first['votes']
  end

  def self.blog(id)
    #get('/elle/ajaxext/GPBlogsVoteGet').parsed_response.reject { |b| b['blog_id'].to_i != id }
    idx = 1
    self.get_classement.each do |b|
      if b['blog_id'].to_i == id
        return "#{idx}. ##{b['blog_id']} - #{b['votes']} votes"
      end
      idx = idx + 1
    end
  end
end

puts Elle.classement
puts Elle.blog(54).inspect
puts Elle.blog(104).inspect
