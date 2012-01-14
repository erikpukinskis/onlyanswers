require 'rubygems'
require 'sinatra'
require 'haml'
require 'rest-client'
require 'yajl'
require 'cgi'
require 'active_support/lazy_load_hooks'
require 'active_support/core_ext/string'

use Rack::Session::Cookie, :secret => ENV['SESSION_SECRET'] || 'This is a secret key that no one will guess~'


get '/' do
  url = 'http://www.reddit.com/r/IAmA.json'
  json = RestClient.get url
  parser = Yajl::Parser.new
  hash = parser.parse(json)
  @interviews = hash["data"]["children"].reject do |hash|
    hash["data"]["title"].include? "equest"
  end.map do |hash|
    data = hash["data"]
    parts = data["permalink"].split("/")
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
      @count += 1
      answers << {:question => question, :asker => asker, :answer => body}
    end

    answers + get_answers(body, author, hash["data"]["replies"])
  end
end

def user_url(user)
  "<a href=\"http://www.reddit.com/user/#{user}\">#{user}</a>"
end

def clean_title(title)
  title.gsub(/I?AMA?[Ai]/i, '').strip.gsub(/^I? ?am an? /i, '').strip.gsub(/[.! ]*$/, '')
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

    %title hello!
    %link{:rel => 'stylesheet', :type => 'text/css', :href => '/base.css'}
  %body
    .page
      .content
        .inner= yield
      .sidebar
        .inner
          %p
            %strong Only Answers
            is a readable noise-free way to read interviews from <a href="http://reddit.com">Reddit</a>'s
            <a href="http://www.reddit.com/r/iama/">IAmA</a> community.

          %p
            Send bug reports, adulation, and DMCA takedown requests to 
            <a href="mailto:onlytheanswers@gmail.com">onlytheanswers@gmail.com</a>.
          
          %p
            <a href="http://snowedin.net">Erik</a> built Only Answers and pays the $30/month hosting 
            bills. Please
            consider <a href="https://www.wepay.com/x1j7o9d">donating a few dollars</a>!


          %p
            If you want to grow a vegetable garden, try my other site, 
            <a href="http://sproutrobot.net">SproutRobot</a>!

@@ index
.home
  %h1 I am a...
  %ul
    - @interviews.each do |key, slug, title, author|
      %li
        %a{:href => "/#{key}/#{slug}"}= clean_title title

@@ interview
%h1
  %a{:href => @url}= @title
  .count= @count
.intro
  = CGI.unescapeHTML(@intro || "")
  \-
  = user_url @author

- @answers.each do |answer|
  %p.question
    = answer[:question]
    \-
    = user_url(answer[:asker])
  %p.answer= answer[:answer]