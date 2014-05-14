class Status < ActiveRecord::Base

  belongs_to :project
  belongs_to :modifier, :class_name=>'Person', :foreign_key=>'last_modifier'
  has_many   :history_counters

  before_save :escape

  def is_current?
    self.updated_at.to_date.cweek == Date.today.cweek
  end
  
  def months_from_creation
    return  (Date.today.year * 12 + Date.today.month) - (self.updated_at.to_date.year * 12 + self.updated_at.to_date.month)
  end
  
  def get_last_change_excel
    return self.last_change_excel if self.last_change_excel
    self.last_change
  end

  def escape
    self.reason                     = html_escape(self.reason)
    self.explanation                = html_escape(self.explanation)
    self.last_change                = html_escape(self.last_change)
    self.reporting                  = html_escape(self.reporting)
    self.feedback                   = html_escape(self.feedback)
    self.actions                    = html_escape(self.actions)
    self.operational_alert          = html_escape(self.operational_alert)
    self.pratice_spider_gap         = html_escape(self.pratice_spider_gap)
    self.deliverable_spider_gap     = html_escape(self.deliverable_spider_gap)
  end

  def copy_status_to_reporting
    Status.record_timestamps  = false
    self.reporting      = self.reason
    self.reporting_at   = self.reason_updated_at
    self.save
    Status.record_timestamps  = true
  end

end

