class SessionsController < ApplicationController
  before_filter :verify_owner, :only => [:update, :edit]
  
  make_resourceful do
    actions :show, :new, :edit, :update

    before :show do
      @similar_sessions = []
      @similar_sessions = current_object.recommended_sessions
    end
  end

  def index
    @sessions = Event.current_event.sessions
  end

  def create
    build_object
    load_object
    
    if logged_in?
      current_object.participant = current_participant
    else
      name, email = object_parameters[:name], object_parameters[:email]

      participant = Participant.first(:conditions => {:email => email}) || Participant.create(:email => email, :name => name)
      
      if !participant.new_record?
        session[:participant_id] = participant.id
        current_object.participant = participant
      else
        current_object.errors.add_to_base("The participant is invalid.") # FIXME: better message
      end
    end

    current_object.event = Event.current_event

    if verify_recaptcha(:model => current_object, :message => "Please try entering the captcha again.") && current_object.save
      flash[:notice] = "Thanks for adding your session."
      redirect_to current_object
    else
      render :action => 'new'
    end
  end

  STOP_WORDS = Set.new(['session', 'etc', 'just', 'presentation', 'get', 'discussion'])

  def words
    @sessions = Event.current_event.sessions
    @words = @sessions.map(&:description).
      map { |desc| BlueCloth.new(desc).to_html }.
      map { |md| RailsSanitize.full_sanitizer.sanitize(md) }.
      map(&:downcase).
      join(" ").
      split(/\s+/).
      reject { |w| STOP_WORDS.include?(w) }.
      join(" ") 
  end

  def export
    @sessions = Event.current_event.sessions.all(:order => 'lower(title) asc')
    render :layout => 'export'
  end

  def popularity
    @sessions = Event.current_event.sessions.with_attendence_count.all(:order => "COALESCE(attendence_count, 0) desc")
    render :layout => 'export'
  end

  private

  def verify_owner
    if current_object.participant != current_participant
      redirect_to current_object
    end
  end
end
