class Workstream < ActiveRecord::Base

  #has_many :projects, :foreign_key=>'workstream', :class_name=>'Project'
  
  def projects
    Project.find(:all, :conditions=>["workstream=?", self.name]).sort_by { |p| [-p.get_status.status, p.full_name]}
  end
  
  def non_green_projects
    projects.select {|p| p.has_requests and p.get_status.status != 1}
  end
  
  def projects_with_new_reason
    projects.select {|p| s = p.get_status; p.has_requests and s.reason_updated_at > s.reporting_at }
  end
  
end
