namespace :karafka do
  desc "Prepara o ambiente e inicia o Karafka server (use SKIP_SETUP=true para pular a preparação)"
  task :start => :environment do
    skip_setup = ENV["SKIP_SETUP"] == "true"

    unless skip_setup
      puts "🔧 Preparando ambiente..."
      system("bundle check || bundle install") || abort("Erro no bundle install")
      system("bundle exec karafka topics create") || abort("Erro ao criar tópicos no Kafka")
      system("DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rails db:drop db:create") || abort("Erro ao recriar DB")
      system("bundle exec rails db:prepare") || abort("Erro no db:prepare")
    else
      puts "⏩ Pulando preparação, iniciando Karafka..."
    end

    exec("bundle exec karafka server")
  end
end