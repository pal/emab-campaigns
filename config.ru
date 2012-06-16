require "app"
if ENV['RAILS_ENV'] == 'production'
   ENV['GEM_PATH'] = '/home/emab/.gems' + ':/usr/lib/ruby/gems/1.8'
end
run Sinatra::Application
