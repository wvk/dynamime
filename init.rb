require File.dirname(__FILE__) + '/lib/dynamime'
require File.dirname(__FILE__) + '/lib/rails_hacks'

case RAILS_GEM_VERSION
when /^2.1/
  require File.dirname(__FILE__) + '/lib/rails_21_hacks'
when /^2.3/
  require File.dirname(__FILE__) + '/lib/rails_23_hacks'
else
  raise 'Dynamime currently does not support your Rails version!'
end
