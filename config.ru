require 'bundler/setup'
require 'sinatra'
require './app'

root_dir = File.dirname(__FILE__)

set :root, root_dir
set :app_file, File.join(root_dir, 'app.rb')
disable :run

run Sinatra::Application
