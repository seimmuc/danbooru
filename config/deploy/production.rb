set :user, "danbooru"
set :rails_env, "production"
server "railsproduction", :roles => %w(web app db), :primary => true, :user => "danbooru"

#set :linked_files, fetch(:linked_files, []).push(".env.production")
