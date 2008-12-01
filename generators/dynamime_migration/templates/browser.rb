class Browser < ActiveRecord::Base
  has_many :user_agents,
           :dependent => :destroy
  has_many :hardware_platforms,
           :through => :user_agents,
           :uniq    => true

  validates_length_of :name,
                      :minimum => 2
  validates_uniqueness_of :name
end
