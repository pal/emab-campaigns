set :domain, "emab.subtree.se"
set :application, "app"
set :deploy_to, "/home/emab/emab-campaigns-app"

set :user, "emab"
set :use_sudo, false

set :scm, :git
set :repository, "git@github.com:pal/emab-campaigns.git"
set :branch, 'master'
set :git_shallow_clone, 1

role :web, domain
role :app, domain
role :db, domain, :primary => true

set :deploy_via, :remote_cache

namespace :deploy do
  task :start do ; end
  task :stop do ; end

  # Assumes you are using Passenger
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end

  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)

    # mkdir -p is making sure that the directories are there for some SCM's that don't save empty folders
    run <<-CMD
rm -rf #{latest_release}/log &&
mkdir -p #{latest_release}/public &&
mkdir -p #{latest_release}/tmp &&
ln -s #{shared_path}/log #{latest_release}/log
CMD

    if fetch(:normalize_asset_timestamps, true)
      stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
      asset_paths = %w(images css).map { |p| "#{latest_release}/public/#{p}" }.join(" ")
      run "find #{asset_paths} -exec touch -t #{stamp} {} ';'; true", :env => { "TZ" => "UTC" }
    end
  end

  task :symlink_dreamhost_domain, :roles => :app do
	 	Capistrano::CLI.ui.say("*"*70)
	 	Capistrano::CLI.ui.say("WARNING! This will erase EVERYTHING stored in /home/#{user}/#{domain}")
	 	Capistrano::CLI.ui.say("Are you absolutely sure you wish to continue?")
	 	Capistrano::CLI.ui.say("There is no way to undelete if you continue!")
	 	Capistrano::CLI.ui.say("*"*70)
		
		agree = Capistrano::CLI.ui.agree("Continue (Yes, [No]) ") do |q|
			q.default = 'n'
		end
		if agree
		 	Capistrano::CLI.ui.say("Removing old data")
	    run "#{try_sudo} rm -rf /home/#{user}/#{domain}"
    	run "#{try_sudo} ln -s #{current_path} #{domain}"
		else
		 	Capistrano::CLI.ui.say("Delete aborted")
		end
  end
	  	
	after "deploy:setup", "deploy:symlink_dreamhost_domain"


end