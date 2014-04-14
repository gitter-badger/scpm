class ChecklistsController < ApplicationController

  layout 'tools'

  def show
    milestone_id = params[:id]
    @milestone = Milestone.find(milestone_id)

    @requests   = @milestone.project.requests.sort_by{ |r| [r.work_package, r.milestone]}
    @milestone_requests = @milestone.active_requests

    @items = ChecklistItem.find(:all, :conditions=>["milestone_id=? and checklist_items.parent_id=0",milestone_id], 
      :order=>"checklist_item_templates.order", 
      :joins=>"LEFT OUTER JOIN checklist_item_templates ON checklist_item_templates.id=checklist_items.template_id")
    @items = @items.select{|i| i.ctemplate.ctype!='folder' or i.children.size > 0}
    
    render(:layout=>false)
  end

  def last
    @items = ChecklistItem.find(:all, :conditions=>"status!=0", :order=>"updated_at desc", :limit=>20)
    @projects = @items.map{|i| i.ctemplate.is_transverse==1? i.project : i.milestone.project }.uniq
  end

  def set_next_status
    id = params[:id]
    @item = ChecklistItem.find(id)
    @item.status = @item.ctemplate.values.next_value(@item.status)
    @item.save
  end

  def check
    # check closed milestones with open checklist items
    @milestones = Milestone.find(:all, :conditions=>"done=1").select{ |m|
      m.checklist_items.select{ |i|
        i.ctemplate.ctype!='folder' and i.status==0
        }.size > 0
     }.sort_by { |m| [m.project.full_name, m.name] }
    @checklist_item_count = ChecklistItem.count
  end

  def cleanup
    ChecklistItem.all.select{|i| !i.good?}.each(&:destroy)
    render(:nothing=>true)
  end

  def destroy
    id = params[:id]
    ChecklistItem.destroy(id)
    render(:nothing=>true)
  end

end
