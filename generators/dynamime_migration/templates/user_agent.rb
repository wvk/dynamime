class UserAgent < ActiveRecord::Base
  belongs_to :browser
  belongs_to :hardware_platform

  validates_uniqueness_of :substring,
                          :message => 'There is already a user agent with the exact same UA-string.'
  validates_presence_of :browser_id,
                        :hardware_platform_id

  def view_mime_type
    Dynamime::Type.exists?(view_platform) ? Dynamime::Type.lookup_by_extension(view_platform) : nil
  end

  def view_mime_type=(type)
    view_platform = "#{type.to_sym}"
  end

  def is_mobile?
    view_mime_type == Dynamime::MOBILE or view_mime_type.subtype_of?(:mobile)
  end

  def full_name
    '%s on %s' % [browser.name, hardware_platform.name]
  end
end
