#!/bin/sh
apk update && apk upgrade
apk add --no-cache g++ make git bash
cd /home && touch Gemfile.lock && \
  rm Gemfile.lock && \
  bundle install && \
  bundle exec rake test:ci


RUBY_VERSION=`ruby -e 'puts RUBY_VERSION'`

echo "RUBY $RUBY_VERSION"

if [[ $RUBY_VERSION = "2.5"* ]] ;
then
  cd www && bundle install && \
  bundle exec jekyll build -d public
fi


