If you want to host your own version of Only Answers, you will need to:

1. Install Git, Ruby and RubyGems
2. Install the bundler and heroku gems:

        gem install bundler heroku

3. Download and install the code:

        git clone git://github.com/erikpukinskis/onlyanswers.git answers_spinoff
        cd answers_spinoff
        bundle install

4. Run it on your computer:

        shotgun main.rb

5. Visit [http://localhost:9393](http://localhost:9393) to see it working.

6. Deploy to Heroku:

        heroku create
        git push heroku master
        heroku open

And it should be running live on the intarwebs!