require 'rbtree'

# This represents a device as modeled in the WURFL database/XML file.
# A WURFL device basically has a UA String by thich it is recognised,
# an ID and a "fallback" device, from which it inherits a set of
# common properties, called 'capabilities'.
# for a more concise and comprehensive documentation on the WURFL,
# see: http://wurfl.sourceforge.net/backgroundinfo.php

class WurflDevice
  # RBtree brovides a faster way of looking up entries by their keys
  # than a Hash (O(log(n)) vs. O(n)) -- if the gem is not present,
  # we use a Hash instead.
  begin
    @@devices = RBTree.new
  rescue
    @@devices = Hash.new
  end

  cattr_accessor :devices
  attr_accessor :id, :user_agent, :fall_back, :actual_device_root, :capabilities

  def initialize(id, user_agent, fall_back, actual_device_root=false)
    @id, @user_agent, @fall_back, @actual_device_root = id, user_agent, fall_back, actual_device_root
    @capabilities = HashWithIndifferentAccess.new
    @@devices[@id] = self
  end

  def parent_device
    @@devices[@fall_back]
  end

  # returns all _direct_ children of the current device.
  def children
    @@devices.find {|i, v| i == @id }
  end

  # gets a capability. If it is not defined for the current device,
  # it is retrieved from the parent device and so on.
  def [](name)
    @capabilities[name] || (parent_device ? parent_device[name] : nil)
#     @capabilities[name] = parent_device[name] if parent_device
  end

  # sets a capability for the current device. You can specify your
  # own capabilities, i.e. you are not restricted to those listed
  # on the WURFL website.
  def []=(name, value)
    @capabilities[name] = value
  end

  # retrieves the device with the id <name>
  def self.[](name)
    @@devices[name]
  end

  # sets the device with the id <name> to <new_device>
  def self.[]=(name, new_device)
    @@devices[name] = new_device
  end
end
