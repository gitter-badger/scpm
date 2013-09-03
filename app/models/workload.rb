class Workload

  include ApplicationHelper

  attr_reader :name,  # person's name
    :weeks,           # arrays of week's names '43', '44', ...
    :wl_weeks,        # array of week ids '201143'
    :months,          # "Oct"
    :days,            # week days display per week: "17-21"
    :opens,           # total of worked days per week (5 - nb of holidays)
    :person,
    :person_id,
    :wl_lines,        # arrays of loads, all lines (filtered and not filtered)
    :displayed_lines, # only filtered lines
    :line_sums,       # sum of days per line of workload
    :ctotals,         # total days planned per week including not bundle days (holidays and other lines) {:id=>w, :value=>col_sum(w, @wl_lines)}
    :availability,    # total days of availability {:days=>xxx, :percent=>yyy}
    :sum_availability,# sum of availabity days for the next 8 weeks
    :cprodtotals,     # total days planned per week on production only {:id=>w, :value=>col_prod_sum(w, @wl_lines)}
    :percents,        # total percent per week: {:name=>'cpercent', :id=>w, :value=>percent.round.to_s+"%", :precise=>percent}
    :next_month_percents,         # next 5 weeks capped (including current)
    :three_next_months_percents,  # next 3 months capped (was _after_ the 5 coming weeks but changed later including next 5 weeks)
    :total,                       # total number of days planned (including past weeks)
    :planned_total,               # total number of days planned (current week and after)
    :sdp_remaining_total,         # SDP remaining, including requests to be validated (non SDP task)
    :to_be_validated_in_wl_remaining_total, # total of requests to be validated planned in workloads
    :nb_total_lines,  # total before filters
    :nb_current_lines,# total after filters
    :nb_hidden_lines, # difference (filtered)
    :staffing         # nb of person needed per week

  # options can have
  # :only_holidays => true
  def initialize(person_id, options = {})
    @person     = Person.find(person_id)
    raise "could not find this person by id '#{person_id}'" if not @person
    @person_id  = person_id
    @name       = @person.name

    # calculate lines
    cond = ""
    cond += " and wl_type=300" if options[:only_holidays] == true
    @wl_lines   = WlLine.find(:all, :conditions=>["person_id=?"+cond, person_id], :include=>["request","wl_line_task","person"], :order=>APP_CONFIG['workloads_lines_sort'])
    #Rails.logger.debug "\n===== hide_lines_with_no_workload: #{options[:hide_lines_with_no_workload]}\n\n"
    if options[:only_holidays] != true
      if @wl_lines.size == 0 or @wl_lines.select {|l| l.wl_type==ApplicationController::WL_LINE_HOLIDAYS}.size == 0
        @wl_lines  << WlLine.create(:name=>"Holidays", :request_id=>nil, :person_id=>person_id, :wl_type=>ApplicationController::WL_LINE_HOLIDAYS)
      end
      if APP_CONFIG['automatic_except_line_addition']
        if @wl_lines.size == 0 or @wl_lines.select {|l| l.wl_type==ApplicationController::WL_LINE_EXCEPT and (l.name =~ /Other/)}.size == 0
          @wl_lines  << WlLine.create(:name=>"Other (out of #{APP_CONFIG['project_name']})", :request_id=>nil, :person_id=>person_id, :wl_type=>ApplicationController::WL_LINE_EXCEPT)
        end
        if @wl_lines.size == 0 or @wl_lines.select {|l| l.wl_type==ApplicationController::WL_LINE_EXCEPT and (l.name =~ /#{APP_CONFIG['project_name']} AVV/)}.size == 0
          @wl_lines  << WlLine.create(:name=>"#{APP_CONFIG['project_name']} AVV", :request_id=>nil, :person_id=>person_id, :wl_type=>ApplicationController::WL_LINE_EXCEPT)
        end
      end
    end
    @nb_total_lines = @wl_lines.size
    # must be after the preceding test as we suppress line and if wl_lines.size is 0 then we create a new Holidays line
    if options[:hide_lines_with_no_workload]
      @displayed_lines = @wl_lines.select{|l| l.near_workload > 0}
    else
      @displayed_lines = @wl_lines
    end
    @nb_current_lines = @displayed_lines.size
    @nb_hidden_lines  = @nb_total_lines - @nb_current_lines
    from_day    = Date.today - (Date.today.cwday-1).days
    farest_week = wlweek(from_day+APP_CONFIG['workloads_months'].to_i.months)
    @wl_weeks   = []
    @weeks      = []
    @opens      = []
    @ctotals    = []
    @cprodtotals= []
    @availability = []
    @percents   = []
    @months     = []
    @days       = []
    @staffing   = []
    month = Date::ABBR_MONTHNAMES[(from_day+4.days).month]
    month_displayed = false
    nb = 0
    iteration                   = from_day
    @next_month_percents        = 0.0
    @three_next_months_percents = 0.0
    @sum_availability           = 0
    while true
      w = wlweek(iteration) # output: year + week ("201143")
      break if w > farest_week or nb > 100*4
      # months
      if Date::ABBR_MONTHNAMES[(iteration+4.days).month] != month
        month = Date::ABBR_MONTHNAMES[(iteration+4.days).month]
        month_displayed = false
      end
      if not month_displayed
        @months   << month
        month_displayed = true
      else
        @months << ''
      end
      @days << filled_number(iteration.day,2) + "-" + filled_number((iteration+4.days).day,2)
      @wl_weeks << w
      @weeks    << iteration.cweek
      company = Company.find_by_id(Person.find_by_id(person_id).company_id)
      raise "Company doesn't exist for this person" if company.nil?
      @opens    << 5 - WlHoliday.get_from_week_and_company(w,company)

      if @wl_lines.size > 0
        col_sum = col_sum(w, @wl_lines)
        @ctotals        << {:name=>'ctotal', :id=>w, :value=>col_sum}
        @cprodtotals    << {:id=>w, :value=>col_prod_sum(w, @wl_lines)}
        if @opens and @opens.last > 0
          percent = (@ctotals.last[:value] / @opens.last)*100
        else
          percent = 100
        end
        open    = @opens.last
        avail   = [0,(open-col_sum)].max
        if open > 0
          avail_percent = (avail/open).round
        else
          avail_percent = 0
        end
        if person.is_virtual==1 and open > 0
          @staffing << col_sum / open
        else
          @staffing << 0
        end
        @availability   << {:name=>'avail',:id=>w, :avail=>avail, :value=>(avail==0 ? '' : avail), :percent=>avail_percent}
        @sum_availability += (avail==0 ? '' : avail).to_f if nb<=8
        @next_month_percents += capped_if_option(percent) if nb < 5
        @three_next_months_percents += capped_if_option(percent) if nb >= 0 and nb < 0+12 # if nb >= 5 and nb < 5+12 # 28-Mar-2012: changed
        @percents << {:name=>'cpercent', :id=>w, :value=>percent.round.to_s+"%", :precise=>percent}
      end
      iteration = iteration + 7.days
      nb += 1
    end
    @next_month_percents        = (@next_month_percents / 5).round
    @three_next_months_percents = (@three_next_months_percents / 12).round

    # sum the lines
    @line_sums            = Hash.new
    today_week            = wlweek(Date.today)
    @total                = 0
    @planned_total        = 0
    @sdp_remaining_total  = 0
    @to_be_validated_in_wl_remaining_total = 0
    for l in @wl_lines
      @line_sums[l.id] = Hash.new
      #@line_sums[l.id][:sums] = l.wl_loads.map{|load| (load.week < today_week ? 0 : load.wlload)}.inject(:+)
      @line_sums[l.id][:sums] = l.planned_sum
      @total          += l.sum if l.wl_type <= 200
      @planned_total  += @line_sums[l.id][:sums] if l.wl_type <= 200 and @line_sums[l.id][:sums]
      if l.sdp_tasks
        @sdp_remaining_total += l.sdp_tasks_remaining.to_f
        @line_sums[l.id][:init]      = l.sdp_tasks_initial
        @line_sums[l.id][:balance]   = l.sdp_tasks_balancei
        @line_sums[l.id][:remaining] = l.sdp_tasks_remaining
      elsif l.request
        s = round_to_hour(l.request.workload2)
        if l.request.sdp == "No"
          @line_sums[l.id][:init]      = 'no sdp'
          @line_sums[l.id][:balance]   = 'N/A'
          @line_sums[l.id][:remaining] = s
          @sdp_remaining_total        += s
          @to_be_validated_in_wl_remaining_total += s
        else
          r = l.request.sdp_tasks_remaining_sum({:trigram=>@person.trigram})
          #r = s if r == 0.0
          @line_sums[l.id][:init]      = l.request.sdp_tasks_initial_sum({:trigram=>l.person.trigram})
          @line_sums[l.id][:balance]   = l.request.sdp_tasks_balancei_sum({:trigram=>l.person.trigram})
          @line_sums[l.id][:remaining] = r
          @sdp_remaining_total        += r
        end
      else
        @line_sums[l.id][:init]      = 0.0
        @line_sums[l.id][:remaining] = 0.0
        @line_sums[l.id][:balancei]  = 0.0
      end
    end
  end

  def col_sum(w, wl_lines)
    wl_lines.map{|l| l.get_load_by_week(w)}.inject(:+)
  end

  def col_prod_sum(w, wl_lines)
    wl_lines.select{|l| l.wl_type==100}.map{|l| l.get_load_by_week(w)}.inject(:+)
  end

  # not DRY (already in application_controller)
  def round_to_hour(f)
    (f/0.125).round*0.125
  end

  def remain_to_plan_days
    @sdp_remaining_total - @planned_total
  end

  # Will generate a hash of hash following this format :
  # lines_by_stream[stream.id]["prev"]        = Previsional total (QS + Spider) for this stream
  # lines_by_stream[stream.id]["sum"]         = Total of imputation (QS + Spider) for this stream
  # lines_by_stream[stream.id]["qs_prev"]     = Previsional load for QS of this stream
  # lines_by_stream[stream.id]["qs_sum"]      = Total of imputation for QS of this stream
  # lines_by_stream[stream.id]["spider_prev"] = Previsional load for Spider of this stream
  # lines_by_stream[stream.id]["spider_sum"]  = Total of imputation for Spider of this stream
  def get_qr_qwr_wl_lines_by_streams
    lines_by_streams = Hash.new
    # Create arrays for each stream
    Stream.find(:all).each do |s|
      # lines_by_streams[s.id]                = Array.new
      lines_by_streams[s.id]                = Hash.new
      lines_by_streams[s.id]["prev"]        = 0
      lines_by_streams[s.id]["sum"]         = 0
      lines_by_streams[s.id]["qs_prev"]     = 0
      lines_by_streams[s.id]["spider_prev"] = 0
      lines_by_streams[s.id]["qs_sum"]      = 0
      lines_by_streams[s.id]["spider_sum"]  = 0
    end
    # Add wl_lines to corresponding stream
    wl_lines.each { |wl|
      if wl.project and wl.project.workstream!=''
        # Stream
        s = Stream.find_with_workstream(wl.project.workstream)
        # Previsional
        if(wl.wl_type == 110)
          lines_by_streams[s.id]["prev"]        = lines_by_streams[s.id]["prev"]    + (wl.project.calcul_qs_previsional.to_f * APP_CONFIG['qs_load'].to_f)
          lines_by_streams[s.id]["qs_prev"]     = lines_by_streams[s.id]["qs_prev"] + (wl.project.calcul_qs_previsional.to_f * APP_CONFIG['qs_load'].to_f)
          lines_by_streams[s.id]["qs_sum"]      = lines_by_streams[s.id]["qs_sum"]  + wl.planned_sum.to_f
          lines_by_streams[s.id]["sum"]         = lines_by_streams[s.id]["sum"]     + wl.planned_sum.to_f
        elsif(wl.wl_type == 120)
          lines_by_streams[s.id]["prev"]        = lines_by_streams[s.id]["prev"]        + (wl.project.calcul_spider_previsional.to_f * APP_CONFIG['spider_load'].to_f)
          lines_by_streams[s.id]["spider_prev"] = lines_by_streams[s.id]["spider_prev"] + (wl.project.calcul_spider_previsional.to_f * APP_CONFIG['spider_load'].to_f)
          lines_by_streams[s.id]["spider_sum"]  = lines_by_streams[s.id]["spider_sum"]  + wl.planned_sum.to_f
          lines_by_streams[s.id]["sum"]         = lines_by_streams[s.id]["sum"]         + wl.planned_sum.to_f
        end
      end
    }
    return lines_by_streams
  end

private

  def capped_if_option(percent)
    return [percent, 100].min if APP_CONFIG['consolidation_capped_next_weeks']
    percent
  end

end
