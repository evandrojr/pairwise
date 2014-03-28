class ChoicesController < InheritedResources::Base
  respond_to :xml, :json
  actions :show, :index, :create, :update, :new
  belongs_to :question
  has_scope :active, :type => :boolean, :only => :index

  before_filter :authenticate

  def index
    if params[:limit]
      @question = current_user.questions.find(params[:question_id])

      find_options = {:conditions => {:question_id => @question.id},
        :limit => params[:limit].to_i,
        :order => 'score DESC'
      }

      find_options[:conditions].merge!(:active => true) unless params[:include_inactive]

      find_options[:include] = [:creator]

      if(params[:ignore_flagged])
        find_options[:include] << :flags
        find_options[:conditions].merge!({:flags => {:id => nil}})
      end

      find_options.merge!(:offset => params[:offset]) if params[:offset]

      @choices = Choice.find(:all, find_options)

    else
      @question = current_user.questions.find(params[:question_id])

      sort_by = "score"
      sort_order = "DESC"

      if !params[:order].blank?

        if params[:order][:sort_order].downcase == "asc" or params[:order][:sort_order].downcase == "desc"
          sort_order = params[:order][:sort_order].downcase
        end

        case params[:order][:sort_by].downcase
          when "data"
            sort_by = "choices.data"
          when "created_date"
            sort_by = "choices.created_at"
          when "visitor_identifier"
            sort_by = "visitors.identifier"
          else
            sort_by = "score"
        end

      end

      order = "#{sort_by} #{sort_order}"

      find_options = {
        :include  => [:creator],
        :conditions => {},
        :order => order
      }

      if params[:filter] && !params[:filter][:data].blank?
        conditions = []
        conditions << ['lower(data) like ?', "%#{params[:filter][:data].downcase}%"]
        find_options[:conditions] = [conditions.map{|c| c[0] }.join(" AND "), *conditions.map{|c| c[1..-1] }.flatten]
      end

      if (!params[:reproved].blank?)
        @choices = @question.choices(true).reproved.find(:all, find_options)
      else
        if params[:inactive_ignore_flagged]
          @choices = @question.choices(true).inactive_ignore_flagged.find(:all, find_options)
        elsif params[:inactive]
          @choices = @question.choices(true).inactive.find(:all, find_options)
        else
          unless params[:include_inactive]
            @choices = @question.choices(true).active.find(:all, find_options)
          else
            @choices = @question.choices.find(:all, find_options)
          end
        end
      end

    end

    index! do |format|
      format.xml { render :xml => @choices.to_xml(:only => [ :data, :score, :id, :active, :created_at, :wins, :losses], :methods => [:user_created, :creator_identifier, :reproved])}
    end

  end

  # method added to provide more choices search options and
  # provide better tool for manage the suggestions users provided
  def search
      @choices = Choice.search(params)
      index! do |format|
        format.xml { render :xml => @choices.to_xml(:only => [ :data, :score, :id, :active, :created_at, :wins, :losses], :methods => [:user_created, :creator_identifier])}
      end
  end
  
  def votes
    @choice = Choice.find(params[:id])
    render :xml => @choice.votes.to_xml
  end

  def create

    visitor_identifier = params[:choice].delete(:visitor_identifier)

    visitor = current_user.default_visitor
    if visitor_identifier
      visitor = current_user.visitors.find_or_create_by_identifier(visitor_identifier)
    end
    params[:choice].merge!(:creator => visitor)

    @question = current_user.questions.find(params[:question_id])
    params[:choice].merge!(:question_id => @question.id)


    @choice = Choice.new(params[:choice])
    create!
  end

  def flag
    @question = current_user.questions.find(params[:question_id])
    @choice = @question.choices.find(params[:id])

    flag_params = {:choice_id => params[:id].to_i, :question_id => params[:question_id].to_i, :site_id => current_user.id}

    if explanation = params[:explanation]
	    flag_params.merge!({:explanation => explanation})
    end
    if visitor_identifier = params[:visitor_identifier]
            visitor = current_user.visitors.find_or_create_by_identifier(visitor_identifier)
	    flag_params.merge!({:visitor_id => visitor.id})
    end
    respond_to do |format|
	    if @choice.deactivate!
                    flag = Flag.create!(flag_params)
		    format.xml { render :xml => @choice.to_xml, :status => :created }
		    format.json { render :json => @choice.to_json, :status => :created }
	    else
		    format.xml { render :xml => @choice.errors, :status => :unprocessable_entity }
		    format.json { render :json => @choice.to_json }
	    end
    end

  end

  def update
    # prevent AttributeNotFound error and only update actual Choice columns, since we add extra information in 'show' method
    choice_attributes = Choice.new.attribute_names
    params[:choice] = params[:choice].delete_if {|key, value| !choice_attributes.include?(key)}
    Choice.transaction do
      # lock question since we'll need a lock on it later in Choice.update_questions_counter
      @question = current_user.questions.find(params[:question_id], :lock => true)
      @choice = @question.choices.find(params[:id])
      update!
    end
  end

  def show
    @question = current_user.questions.find(params[:question_id])
    @choice = @question.choices.find(params[:id])
    response_options = {}
    response_options[:include] = :versions if params[:version] == 'all'

    respond_to do |format|
      format.xml { render :xml => @choice.to_xml(response_options) }
      format.json { render :json => @choice.to_json(response_options) }
    end
  end

end

