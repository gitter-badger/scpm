class ChecklistItem < ActiveRecord::Base

  has_many :children, :class_name=>"ChecklistItem", :foreign_key=>"parent_id"
  belongs_to :ctemplate, :class_name=>"ChecklistItemTemplate", :foreign_key=>"template_id"

  def css_class
    case self.ctemplate.ctype
      when 'folder'
        'checklist_item folder'
      else
        ''
    end
  end

end

