class Mailer < ActionMailer::Base

  include ApplicationHelper

  def mail(recipient, subject = "Hi", body = "Test de mail")
    @from        = APP_CONFIG['generic_email_address']
    @recipients  = recipient
    @subject     = subject
    @body        = body
    content_type "text/html; charset=utf-8"
  end

  def status_change(project)
    @from       = APP_CONFIG['status_change_email_source']
    @recipients = APP_CONFIG['status_change_email_destination']
    @subject    = "[EISQ] Status change - #{project.full_name}"
    @project    = project
  end

  def risk_change(risk)
    @from       = APP_CONFIG['risk_change_email_source']
    @recipients = APP_CONFIG['risk_change_email_destination']
    @subject    = "[EISQ] Risk change - #{risk.project.full_name}"
    @risk       = risk
  end

  def backup_delete(backup)
    @from       = APP_CONFIG['backup_change_email_source']
    @recipients = backup.backup.email
    @subject    = "[EISQ] Backup deleted"
    @backup     = backup
  end 

  # search all people without work and send a reminder to update the workload
  def workload_alerts
    people = Person.find(:all, :conditions=>"has_left=0 and is_supervisor=0 and is_transverse=0", :order=>"name")
    @workloads = []
    for p in people
      @workloads << Workload.new(p.id,{},{})
    end
    @workloads = @workloads.select{|w| w.next_month_percents < 95 or w.next_month_percents > 115}.sort_by {|w| [w.next_month_percents]}

    @from       = APP_CONFIG['workload_alerts_email_source']
    @recipients = APP_CONFIG['workload_alerts_email_destination']
    @subject    = "[EISQ] Workload alerts"
    @headers    = {}
    content_type "text/html; charset=utf-8"
  end

  def daily(person, n, r, am, ac, om, tbv, wl_to_plan, wl_percent_planned)
    render(:nothing=>true) and return if !person or person.email.empty?
    @from        = APP_CONFIG['daily_reminder_email_source']
    @recipients  = person.email+","+APP_CONFIG['daily_reminder_email_destination']
    @subject     = APP_CONFIG['daily_reminder_email_object']+person.name
    @week1       = wlweek(Date.today)
    @week2       = wlweek(Date.today+7.days)
    @person, @new_notes, @requests_to_close, @amendments, @actions, @milestones_with_open_checklists, @tbv, @wl_to_plan, @wl_percent_planned = person, n, r, am, ac, om, tbv, wl_to_plan, wl_percent_planned
    content_type "text/html; charset=utf-8"
  end
  
  def rmt_ci_reminder(person, request_reminder_hash, ciproject_reminder_hash)
    render(:nothing=>true) and return if !person or person.email.empty?
    @from        = APP_CONFIG['request_ci_reminder_email_source']
    @recipients  = person.email+","+APP_CONFIG['request_ci_reminder_email_destination']
    @subject     = APP_CONFIG['request_ci_reminder_email_object']+person.name
    @person, @request_reminder_hash, @ciproject_reminder_hash = person, request_reminder_hash, ciproject_reminder_hash
    content_type "text/html; charset=utf-8"
  end
  
end
