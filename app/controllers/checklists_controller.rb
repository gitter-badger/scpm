class ChecklistsController < ApplicationController

  def show
    milestone_id = params[:id]
    @milestone = Milestone.find(milestone_id)
    @checklists = ChecklistItem.find(:all, :conditions=>["milestone_id=? and checklist_items.parent_id=0",milestone_id], :order=>"checklist_item_templates.order", :joins=>"LEFT OUTER JOIN checklist_item_templates ON checklist_item_templates.id=checklist_items.template_id")
    render(:layout=>false)
  end

end

