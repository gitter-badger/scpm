class ChecklistItem < ActiveRecord::Base

  has_many :children, :class_name=>"ChecklistItem", :foreign_key=>"parent_id"
  belongs_to :ctemplate, :class_name=>"ChecklistItemTemplate", :foreign_key=>"template_id"
  belongs_to :milestone
  belongs_to :request
  belongs_to :project
  belongs_to :parent, :class_name=>"ChecklistItem"

  def late?
    (self.status == 0 and self.ctemplate.deadline and self.milestone.date and
    ((self.milestone.date-self.ctemplate.deadline.days) <= Date.today()))
  end

  def css_class
    case
      when self.ctemplate.ctype=='folder'
        'checklist_item folder'
      when self.late?
        'checklist_item late'
      when self.status > 0
        'checklist_item done'
      else
        'checklist_item'
    end
  end

  def image_name
    self.ctemplate.values.image(self.status)
  end

  def alt
    self.ctemplate.values.alt(self.status)
  end

  def is_qr_qwr
    return true if self.request_id == nil and self.project == nil and self.milestone !=nil
    return false
  end

  def good?
    return false if !self.ctemplate
    if self.ctemplate.is_transverse == 0
      return false if !self.milestone
      return false if !self.ctemplate.milestone_names.map{|m| m.title}.include?(self.milestone.name)
    else
      return false if !self.project
    end

    # Check old is_qr_qwr. If checklistItem created for QR_QWR but the template is not QR_QWR anymore
    if self.is_qr_qwr and self.ctemplate.is_qr_qwr == false# and self.status == 0
      return false
    end

    # Check old is_qr_qwr. If checklistItem created for QR_QWR but the project is not QR_QWR anymore
    if self.is_qr_qwr and self.milestone.project.is_qr_qwr == false# and self.status == 0
      return false
    end 

    # Check if child with no request has a parent with request
    if self.request_id == nil and (self.parent and self.parent.request_id != nil)
      return false 
    end

    # Check requests
    if self.request != nil and self.status != 0
      if !self.ctemplate.workpackages.map{|w| w.title}.include?(self.request.work_package)
        return false
      end
    end

    return true
  end

  def isChildrenActive
    self.children.each do |c|
      if c.status != 0
        return true
      end
    end
    return false
  end

end

