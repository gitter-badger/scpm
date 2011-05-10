class ToolsController < ApplicationController

  include WelcomeHelper

  def index
  end

  def stats_open_projects
    @xml = Builder::XmlMarkup.new(:indent => 1)
    @stats = []
    # global stats
    @workpackages = Request.find(:all, :conditions=>"status !='cancelled' and status != 'to be validated'").map{|r| r.project_name + " / " + get_workpackage_name_from_summary(r.summary, 'No WP')}.uniq.sort
    @projects     = Request.find(:all, :conditions=>"status !='cancelled' and status != 'to be validated'").map{|r| r.project_name}.uniq.sort
    begin
      month_loop(5,2010) { |d|
        requests = Request.find(:all, :conditions=>"date_submitted <= '#{d.to_s}' and status!='to be validated' and status!='cancelled'")
        a = requests.size
        b = requests.map{|r| r.project_name}.uniq.size # work also with a simple group by clause
        c = requests.map{|r| r.project_name + " " + get_workpackage_name_from_summary(r.summary, 'No WP')}.uniq.size
        @stats << [d, a,b,c]
        }
    rescue Exception => e
      render(:text=>"<b>#{e}</b><br>#{e.backtrace.join("<br>")}")
      return
    end

    # by centres
    @centres = []
    for centre in ["EA", "EDE", "EV", "EDC", "EDG", "EDS", "EI", "EDY", "EM", "EMNB", "EMNC"] do
      stats = Array.new
      @centres << {:name=>centre, :stats=>stats}
      begin
        month_loop(5,2010) { |d|
          requests = Request.find(:all, :conditions=>"workstream='#{centre}' and date_submitted <= '#{d.to_s}' and status!='to be validated' and status!='cancelled'")
          a = requests.size
          b = requests.map{|r| r.project_name}.uniq.size # work also with a simple group by clause
          c = requests.map{|r| r.project_name + " " + get_workpackage_name_from_summary(r.summary, 'No WP')}.uniq.size

          stats << [d, a,b,c]
          }
      rescue Exception => e
        render(:text=>"<b>#{e}</b><br>#{e.backtrace.join("<br>")}")
        return
      end
      #puts "#{centre}: #{stats.size}"
    end
    headers['Content-Type'] = "application/vnd.ms-excel"
    headers['Content-Disposition'] = 'attachment; filename="Stats.xls"'
    headers['Cache-Control'] = ''
    render(:layout=>false)
  end

  def test_email
    Mailer::deliver_mail("mfaivremacon@sqli.com")
  end

  def sdp_import
  end

  def do_sdp_upload
    post = params[:upload]
    name =  post['datafile'].original_filename
    directory = "public/data"
    path = File.join(directory, name)
    File.open(path, "wb") { |f| f.write(post['datafile'].read) }
    sdp = SDP.new(path)
    sdp.import
    redirect_to '/tools/sdp_index'
  end

  def sdp_index
    return if SDPTask.count.zero?
    @phases     = SDPPhase.all
    @provisions = SDPTask.find(:all, :conditions=>"iteration='P'", :order=>'title')
    @balancei   = @phases.inject(0) { |sum, p| p.balancei+sum}
    tasks2010   = SDPTask.find(:all, :conditions=>"iteration='2010'")
    tasks2011   = SDPTask.find(:all, :conditions=>"iteration='2011'")
    op2011      = tasks2011.inject(0) { |sum, t| t.initial+sum}
    operational = round_to_hour(op2011*0.11111111111)
    @operational_total = tasks2010.inject(0) { |sum, t| t.initial+sum} + op2011 + operational
    @phases.each { |p|  p.gain_percent = (p.initial==0) ? 0 : (p.balancei/p.initial*100/0.1).round * 0.1 }
    @remaining            = (tasks2010.inject(0) { |sum, t| t.remaining+sum} + tasks2011.inject(0) { |sum, t| t.remaining+sum})
    @remaining_time       = (@remaining/14/18/0.01).round * 0.01
    @theorical_management = round_to_hour((20+10+1.5*14+2*3)*@remaining_time)
    montee      = SDPActivity.find_by_title('Montee en competences').remaining
    souscharges = SDPActivity.find_by_title('Sous charges').remaining
    init        = SDPActivity.find_by_title('Initialization').remaining
    @remaining_management = SDPPhase.find_by_title('Bundle Management').remaining - (montee+souscharges+init)
    @sold                 = @operational_total
    @provisions_remaining = 0
    @provisions_diff      = 0
    @risks_remaining      = 0
    @provisions.each { |p|
      calculate_provision(p,@operational_total,operational)
      @sold += p.initial_should_be
      if p.title == 'Operational Management' or p.title == 'Project Management'
        @provisions_remaining += p.reevaluated_should_be
        @provisions_diff      += p.difference
      elsif p.title == 'Risks'
        @risks_remaining = p.reevaluated
      end
      }
    # Management provisions are already in the management total
    @management_minus_risk        = @remaining_management - @risks_remaining
    @real_balance_and_provisions  = @provisions_diff+@balancei-(@theorical_management - @management_minus_risk)
    @real_balance                 = @real_balance_and_provisions - @provisions_remaining
  end

  def sdp_yes_check
    @task_ids = SDPTask.all.collect{ |t| "'#{t.request_id}'" }.uniq
    @requests = Request.find(:all, :conditions=>"sdp='yes' and request_id not in (#{@task_ids.join(',')})")
  end

  def requests_ended_check
    reqs = Request.find(:all, :conditions=>"resolution='ended' or resolution='aborted'")
    @tasks = []
    reqs.each { |r|
      @tasks += SDPTask.find(:all, :conditions=>"request_id='#{r.request_id}' and remaining > 0")
      }
    ids = @tasks.collect {|t| t.request_id}.uniq.join(',')
    if ids == ""
      @requests = []
    else
      @requests = Request.find(:all, :conditions=>"request_id in (#{ids})")
    end
  end

  def requests_should_be_ended_check
    reqs = Request.find(:all, :conditions=>"status='assigned' and resolution!='ended' and resolution!='aborted'")
    @tasks = []
    reqs.each { |r|
      tmp = SDPTask.find(:all, :conditions=>"request_id='#{r.request_id}'")
      remaining = tmp.inject(0.0)  { |sum, t| sum+t.remaining}
      @tasks += tmp if remaining == 0
      }
    ids = @tasks.collect {|t| t.request_id}.uniq.join(',')
    if ids == ""
      @requests = []
    else
      @requests = Request.find(:all, :conditions=>"request_id in (#{ids})", :order=>"assigned_to")
    end
  end

  def workload_check
    @requests = Request.all
    @tasks = []
    @requests.each { |r|
      @tasks += SDPTask.find(:all, :conditions=>"request_id='#{r.request_id}' and remaining > 0")
      }
  end

  def sdp_people
    tasks = SDPTask.find(:all, :conditions=>"iteration!='HO' and iteration!='P'")
    @trig  = tasks.collect { |t| t.collab }.uniq
    @people = []
    @trig.each { |trig|
      tasks   = SDPTask.find(:all, :conditions=>"collab='#{trig}' and iteration!='HO' and iteration!='P'")
      initial = tasks.inject(0.0) { |sum, t| sum+t.assigned}
      balance = tasks.inject(0.0) { |sum, t| sum+t.balancea}
      if initial > 0
        percent   = ((balance / initial)*100 / 0.1).round * 0.1
        @people << [trig,initial, balance, percent]
      else
        @people << [trig,initial, balance, 0]
      end
      }
    @people = @people.sort_by { |p| [-p[3],-p[1]]}
  end

  def sdp_add
    @requests = Request.find(:all, :conditions=>"sdp='no' and resolution='in progress'")
  end


private

  def round_to_hour(f)
    (f/0.125).round * 0.125
  end

  def calculate_provision(p, total, operational)
    case p.title
      when 'Project Management'
        p.difference = round_to_hour(total * 0.09)-p.initial
      when 'Risks'
        p.difference = round_to_hour(total * 0.04)-p.initial
      when 'Operational Management'
        p.difference = operational - p.initial
      when '(OLD) Quality Assurance'
        p.difference = 0
      when 'Quality Assurance'
        p.difference = round_to_hour(total * 0.02)-p.initial-47.125
      when 'Continuous Improvement'
        p.difference = round_to_hour(total * 0.05)-p.initial
      else
        p.difference = 0
    end
    p.initial_should_be = p.initial + p.difference
    p.reevaluated_should_be = p.reevaluated + p.difference
  end

end

