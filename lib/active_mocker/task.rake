namespace :active_mocker do
  desc('Rebuild mocks.')
  task :build => :environment do
    ActiveMocker::Generate.new
  end

end

['db:schema:load', 'db:migrate', 'db:reset'].each do |task|
  Rake::Task[task].enhance do
    Rake::Task['rebuild_mocks'].invoke
  end
end

