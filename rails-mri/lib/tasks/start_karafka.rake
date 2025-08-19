namespace :karafka do
  desc "Prepara o ambiente (bundle, tópicos Kafka, banco de dados)"
  task :setup => :environment do
    puts "🔧 Preparando ambiente..."
    system("bundle check || bundle install") || abort("Erro no bundle install")
    system("bundle exec karafka topics create") || abort("Erro ao criar tópicos no Kafka")
    system("DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bundle exec rails db:drop db:create") || abort("Erro ao recriar DB")
    system("bundle exec rails db:prepare") || abort("Erro no db:prepare")
    puts "✅ Ambiente preparado com sucesso!"
  end

  desc "Inicia o Karafka server (use SKIP_SETUP=true para pular a preparação)"
  task :start => :environment do
    exec("bundle exec karafka server")
  end
end