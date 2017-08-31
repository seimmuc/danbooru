set :user, "danbooru"
set :rails_env, "production"
server "DanbooruProduction", :roles => %w(web app db), :primary => true, :user => "danbooru"

set :linked_files, fetch(:linked_files, []).push(".env.production")
