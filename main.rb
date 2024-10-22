require 'rubygems'
require 'sinatra'
require 'haml'
require 'rest-client'
require 'yajl'
require 'cgi'
require 'active_support/lazy_load_hooks'
require 'active_support/core_ext/string'
require 'sinatra/content_for'

use Rack::Session::Cookie, :secret => ENV['SESSION_SECRET'] || 'This is a secret key that no one will guess~'

get '/' do
  index
end

get '/after/:key' do
  index params[:key]
end

def index(key=nil)
  url = 'http://www.reddit.com/r/IAmA.json'
  url += "?count=25&after=t3_#{key}" if key

  puts url

  json = RestClient.get url
  parser = Yajl::Parser.new
  hash = parser.parse(json)
  @interviews = hash["data"]["children"].reject do |hash|
    hash["data"]["title"].include? "equest"
  end.map do |hash|
    data = hash["data"]
    parts = data["permalink"].split("/")
    @last_key = parts[4]
    [parts[4], parts[5], data["title"], data["author"]]
  end

  haml :index
end

get '/:key/:slug' do
  @url = "http://www.reddit.com/r/IAmA/comments/#{params[:key]}/#{params[:slug]}"
  json = RestClient.get @url + ".json"
  parser = Yajl::Parser.new
  hash = parser.parse(json)

  meta = hash[0]["data"]["children"][0]["data"]
  @intro = meta["selftext_html"]
  @title = meta["title"]
  @author = meta["author"]

  @count = 0
  @answers = get_answers(nil, nil, nil, hash[1]["data"]["children"])

  haml :interview
end

def get_answers(question, question_id, asker, replies)
  return [] unless replies
  return [] if replies == ""

  if replies.instance_of?(Hash)
    answers = get_answers(question, question_id, asker, replies["data"]["children"])
    return answers
  end

  replies.inject([]) do |answers, hash|
    author = hash["data"]["author"]
    body = hash["data"]["body"]
    if author == @author && question
      @count += 1
      answers << {:question => question, :asker => asker, :answer => body, :id => question_id}
    end

    answers + get_answers(body, hash["data"]["id"], author, hash["data"]["replies"])
  end
end

def user_url(user)
  "<a href=\"http://www.reddit.com/user/#{user}\">#{user}</a>"
end

def clean_title(title)
  punc = "[.!;, ]"
  clean = title.gsub(/AMA?[Ai]#{punc}*$/i, '').strip.gsub(/^I? ?am ?an? /i, '').strip.gsub(/#{punc}*$/, '')
  clean.gsub(/^./, clean[0,1].upcase)
end

def htmlize(t)
  t.strip!
  t.gsub!(/^&gt;([^\n]*)\n/, "<blockquote>\\1</blockquote>")
  t.gsub!(/\n/, "<p>")
  t.gsub!(/\[(.*)\]\((.*)\)/, "<a href=\"\\2\">\\1</a>")
  t
end


__END__

@@ layout
!!! XML
!!!
%html
  %head
    :erb
      <link href='http://fonts.googleapis.com/css?family=Inika:400,700' rel='stylesheet' type='text/css'>
      <link href='http://fonts.googleapis.com/css?family=Magra' rel='stylesheet' type='text/css'>
      <meta name="viewport" content="initial-scale = 1.0"> 

    %title= yield_content :title
    %link{:rel => 'stylesheet', :type => 'text/css', :href => '/base.css'}
  %body
    .page
      .content
        .inner= yield
      .sidebar
        .inner
          %p
            %strong <a href="/">Only Answers</a>
            is a readable noise-free way to read interviews from <a href="http://reddit.com">Reddit</a>'s
            <a href="http://www.reddit.com/r/iama/">IAmA</a> community.

          %p
            <a href="https://www.wepay.com/x1j7o9d">Donate</a>
            |
            <a href="mailto:onlytheanswers@gmail.com">Contact</a>
            | 
            <a href="https://github.com/erikpukinskis/onlyanswers">Source Code</a>

          %p
            Made by <a href="http://snowedin.net">Erik Pukinskis</a>.

          %p
            If you want to grow a vegetable garden, try my other site, 
            <a href="http://sproutrobot.com">SproutRobot</a>! Enter the code
            %span.code IAMAredditor
            for 10% off!

@@ index
- content_for :title do
  Only Answers
.home
  %h1 I am a...
  %ul
    - @interviews.each do |key, slug, title, author|
      %li
        %a{:href => "/#{key}/#{slug}"}= clean_title title
  %a.more{:href => "/after/#{@last_key}"} More

@@ interview
- content_for :title do
  = @title
  \- Only Answers
.interview
  %h1
    %a{:href => @url}= @title
  .intro
    = CGI.unescapeHTML(@intro || "")
    \-
    = user_url @author

  - @answers.each do |answer|
    .question
      = htmlize answer[:question]
      %span.asker
        \-
        %a{:href => "#{@url}/#{answer[:id]}"}= answer[:asker]
    .answer= htmlize answer[:answer]