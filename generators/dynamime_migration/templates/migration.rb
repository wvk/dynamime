class DynamimeMigration < ActiveRecord::Migration
  def self.up
    create_table :browsers do |t|
      t.string :name, :default => '', :null => false
      t.timestamps
    end

    create_table :user_agents do |t|
      t.string  :substring,            :default => '',    :null => false
      t.integer :browser_id,           :default => nil,   :null => false
      t.integer :hardware_platform_id, :default => nil,   :null => false
      t.string  :view_platform,        :default => 'html'
      t.timestamps
    end

    create_table :hardware_platforms do |t|
      t.string :name, :default => '', :null => false
      t.timestamps
    end

    add_index :user_agents, :browser_id
    add_index :user_agents, :hardware_platform_id
  end

  def self.down
    drop_table :browsers
    drop_table :hardware_platforms
    drop_table :user_agents
  end
end
