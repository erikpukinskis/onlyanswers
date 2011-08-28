require 'rubygems'
require 'sinatra'
require 'haml'
require 'rest-client'
require 'yajl'
require 'cgi'

use Rack::Session::Cookie, :secret => ENV['SESSION_SECRET'] || 'This is a secret key that no one will guess~'


get '/' do
  url = 'http://www.reddit.com/r/IAmA.json'
  json = RestClient.get url
  parser = Yajl::Parser.new
  hash = parser.parse(json)
  @interviews = hash["data"]["children"].reject do |hash|
    hash["data"]["title"].include? "AMA Request"
  end.map do |hash|
    data = hash["data"]
    parts = data["permalink"].split("/")
    [parts[4], parts[5], data["title"], data["author"]]
  end

  haml :index
end

get '/:key/:slug' do
  @url = "http://www.reddit.com/r/IAmA/comments/#{params[:key]}/#{params[:slug]}.json"
  json = RestClient.get @url
  parser = Yajl::Parser.new
  hash = parser.parse(json)

  meta = hash[0]["data"]["children"][0]["data"]
  @intro = meta["selftext_html"]
  @title = meta["title"]
  @author = meta["author"]

  @answers = get_answers(nil, nil, hash[1]["data"]["children"])

  haml :interview
end

def get_answers(question, asker, replies)
  return [] unless replies
  return [] if replies == ""

  if replies.instance_of?(Hash)
    answers = get_answers(question, asker, replies["data"]["children"])
    return answers
  end

  replies.inject([]) do |answers, hash|
    author = hash["data"]["author"]
    body = hash["data"]["body"]
    if author == @author && question
      answers << {:question => question, :asker => asker, :answer => body}
    end

    answers + get_answers(body, author, hash["data"]["replies"])
  end
end

def user_url(user)
  "<a href=\"http://www.reddit.com/user/#{user}\">#{user}</a>"
end


__END__

@@ layout
!!! XML
!!!
%html
  %head
    %title hello!
    %link{:rel => 'stylesheet', :type => 'text/css', :href => '/base.css'}
  %body
    = yield

@@ index
.home.page
  %h1 Only Answers
  %ul
    - @interviews.each do |key, slug, title, author|
      %li
        %a{:href => "/#{key}/#{slug}"}= title

@@ interview
.page
  %h1
    %a{:href => @url}= @title
  .intro
    = CGI.unescapeHTML(@intro)
    \-
    = user_url @author

  - @answers.each do |answer|
    %p.question
      = answer[:question]
      \-
      = user_url(answer[:asker])
    %p.answer= answer[:answer]