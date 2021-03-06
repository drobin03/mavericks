set :application, 'mavericks'
set :repo_url, 'git@github.com:drobin03/mavericks.git'
set :theme_name, 'mavericks-theme'


set :scm, :git
set :git_strategy, Capistrano::Git::SubmoduleStrategy

# Branch options
# Prompts for the branch name (defaults to current branch)
#ask :branch, -> { `git rev-parse --abbrev-ref HEAD`.chomp }

# Hardcodes branch to always be master
# This could be overridden in a stage config file
set :branch, :master

set :deploy_to, -> { "/home3/delibet2/public_html/#{fetch(:application)}" }

# Use :info for less verbose output
set :log_level, :debug

# Apache users with .htaccess files:
# it needs to be added to linked_files so it persists across deploys:
# set :linked_files, fetch(:linked_files, []).push('.env', 'web/.htaccess')
set :linked_files, fetch(:linked_files, []).push('.env').push('web/.htaccess')
set :linked_dirs, fetch(:linked_dirs, []).push('web/app/uploads')

set :tmp_dir, "/home3/delibet2/capistrano_tmp"

SSHKit.config.command_map[:bash] = "/usr/bin/bash"
# Patch to make composer work on Bluehost
SSHKit.config.command_map[:composer] = "/ramdisk/php/54/bin/php54-cli /home3/delibet2/composer.phar"

namespace :deploy do
  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      # Your restart mechanism here, for example:
      # execute :service, :nginx, :reload
    end
  end
end

# The above restart task is not run by default
# Uncomment the following line to run it on deploys if needed
# after 'deploy:publishing', 'deploy:restart'

namespace :deploy do
  desc 'Update WordPress template root paths to point to the new release'
  task :update_option_paths do
    on roles(:app) do
      within fetch(:release_path) do
        if test :wp, :core, 'is-installed'
          [:stylesheet_root, :template_root].each do |option|
            # Only change the value if it's an absolute path
            # i.e. The relative path "/themes" must remain unchanged
            # Also, the option might not be set, in which case we leave it like that
            value = capture :wp, :option, :get, option, raise_on_non_zero_exit: false
            if value != '' && value != '/themes'
              execute :wp, :option, :set, option, fetch(:release_path).join('web/wp/wp-content/themes')
            end
          end
        end
      end
    end
  end
end

# The above update_option_paths task is not run by default
# Note that you need to have WP-CLI installed on your server
# Uncomment the following line to run it on deploys if needed
# after 'deploy:publishing', 'deploy:update_option_paths'


# Global bedrock theme path
set :theme_path, Pathname.new('web/app/themes').join(fetch(:theme_name))

# Local Paths
set :local_app_path, Pathname.new(File.dirname(__FILE__)).join('../')
set :local_theme_path, fetch(:local_app_path).join(fetch(:theme_path))
set :local_dist_path, fetch(:local_theme_path).join('dist')
# Remote Paths
set :remote_theme_path, release_path.join(fetch(:theme_path))
set :remote_dist_path, fetch(:remote_theme_path).join('dist')

namespace :assets do
  task :compile do
    run_locally do
      within fetch(:local_theme_path) do
        execute :gulp, '--production'
      end
    end
  end

  task :copy do
    on roles(:web) do
      ld = fetch(:local_dist_path)
      rd = fetch(:remote_dist_path)
      info " Your local distribution path: #{ld} "
      info " Boom!!! Your remote distribution path: #{rd} "
      info " Uploading files to remote "
      upload! fetch(:local_dist_path).to_s, fetch(:remote_dist_path), recursive: true
    end
  end

  task deploy: %w(compile copy)
end

after 'deploy:published', 'assets:deploy'