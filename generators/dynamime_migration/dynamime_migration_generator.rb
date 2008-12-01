class DynamimeMigrationGenerator < Rails::Generator::Base
  def manifest
    record do |m|

      m.directory 'db/migrate'
      m.directory 'test/fixtures'
      m.directory 'app/models'
      m.directory 'lib/tasks'

      m.migration_template 'migration.rb', 'db/migrate'
      m.template 'browsers.yml',           'test/fixtures/browsers.rb'
      m.template 'hardware_platforms.yml', 'test/fixtures/hardware_platforms.rb'
      m.template 'user_agents.yml',        'test/fixtures/user_agents.rb'

      m.template 'browser.rb',           'app/models/browser.rb'
      m.template 'hardware_platform.rb', 'app/models/hardware_platform.rb'
      m.template 'user_agent.rb',        'app/models/user_agent.rb'

      m.template 'wurfl.rake', 'lib/tasts/wurfl.rake'
    end
  end
end
