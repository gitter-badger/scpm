class Person < ActiveRecord::Base

  has_one :company

  def requests
    return [] if self.rmt_user == "" or self.rmt_user == nil
    Request.find(:all, :conditions => "assigned_to='#{self.rmt_user}'", :order=>"workstream, project_name")
  end
  
end

