require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Questions" do
  include IntegrationSupport
  before do
    @user = self.default_user = Factory(:email_confirmed_user)
    @choices = {}
    @questions = Array.new(5){ Factory(:aoi_question, :site => @user) }.each do |q|
      @choices[q.id] = Array.new(rand(10)){ Factory(:choice, :question => q, :active => (rand(2)==1)) }
    end
  end

  describe "GET 'median_votes_per_session'" do
    it "should return the median" do
      Factory.create(:vote, :question => @questions.first)
      get_auth median_votes_per_session_question_path(@questions.first, :format => 'xml')
      response.should be_success
      response.body.should have_tag("median", :text => "1")
    end
  end

  describe "GET 'index'" do
    it "should return an array of questions" do
      get_auth questions_path(:format => 'xml')
      response.should be_success
      response.body.should have_tag("questions question", @questions.size)
    end
      
    it "should not return other users' questions" do
      other_user = Factory(:email_confirmed_user)
      other_questions = Array.new(5){ Factory(:aoi_question, :site => other_user) }

      get_auth other_user, questions_path(:format => 'xml')

      response.should be_success
      response.body.should have_tag "questions question site-id", :count => 5, :text => other_user.id.to_s
      response.body.should_not have_tag "site-id", @user.id.to_s
    end

    it "should return a list of questions for a specific creator" do
      3.times{ Factory(:aoi_question,
                       :site => @user,
                       :local_identifier => "jim") }

      get_auth questions_path(:format => 'xml'), {:creator => "jim"}
      response.should be_success
      response.body.should have_tag("questions question", 3)
      response.body.should have_tag("questions question local-identifier", "jim")
    end

    it "should calculate the total number of user-submitted choices" do
      get_auth questions_path(:format => 'xml'), :user_ideas => true

      response.should be_success
      response.body.should have_tag("question", @questions.size)
      @choices.each_value do |cs|
        response.body.should have_tag("user-ideas", :text => cs.size)
      end
    end

    it "should calculate the number of active user-submitted choices" do
      get_auth questions_path(:format => 'xml'), :active_user_ideas => true

      response.should be_success
      response.body.should have_tag("question", @questions.size)
      @choices.each_value do |cs|
        count = cs.select{|c| c.active}.size
        response.body.should have_tag "active-user-ideas", :text => count
      end
    end

    it "should calculate the number of votes submitted since some date" do
      votes = {}
      @questions.each do |q|
        votes[q.id] = Array.new(20) do
          Factory(:vote, :question => q, :created_at => rand(365).days.ago)
        end
      end
      date = rand(365).days.ago
      get_auth questions_path(:format => 'xml'), :votes_since => date.strftime("%Y-%m-%d")

      response.should be_success
      response.body.should have_tag("question", @questions.size)
      votes.each_value do |vs|
        count = vs.select{|v| v.created_at > date}.size
        response.body.should have_tag("recent-votes", :text => count)
      end
    end

  end

  describe "GET 'new'" do
    it "should return an empty question object" do
      get_auth new_question_path(:format => 'xml')
      response.should be_success
      response.body.should have_tag "question", 1
      response.body.should have_tag "question name", ""
      response.body.should have_tag "question creator-id", ""
      response.body.should have_tag "question created-at", ""
    end      
  end 

  describe "POST 'create'" do
    before { @visitor = Factory.create(:visitor, :site => @api_user) }

    it "should fail when required parameters are omitted" do
      post_auth questions_path(:format => 'xml')
      response.should_not be_success
    end

    it "should return a question object given no optional parameters" do
      pending("choice count doesn't reflect # seed ideas") do
        params = { :question => { :visitor_identifier => @visitor.identifier, :ideas => "foo\r\nbar\r\nbaz" } }

        post_auth questions_path(:format => 'xml'), params

        response.should be_success
        response.should have_tag "question", 1
        response.should have_tag "question creator-id", @visitor.id.to_s
        response.should have_tag "question choices-count", 3
      end
    end

    it "should correctly set optional attributes" do
      params = {
        :question => {
          :visitor_identifier => @visitor.identifier,
          :ideas => "foo\r\nbar\r\nbaz",
          :name => "foo",
          :local_identifier => "bar",
          :information => "baz" } }

      post_auth questions_path(:format => 'xml'), params
      response.should be_success
      response.should have_tag "question", 1
      response.should have_tag "question creator-id", @visitor.id.to_s
      # response.should have_tag "question choices-count", 3
      response.should have_tag "question name", "foo"
      response.should have_tag "question local-identifier", "bar"
      response.should have_tag "question information", "baz"
    end
  end

  describe "POST 'export'" do
    before { @question = Factory.create(:aoi_question, :site => @api_user) }

    it "should fail without any of the required parameters" do
      post_auth export_question_path(@question,  :format => 'xml')
      response.should be_success
      response.body.should =~ /Error/
    end

    it "should fail given invalid parameters" do
      params = { :type => "ideas", :response_type => "foo", :redisk_key => "bar" }
      post_auth export_question_path(@question)
      response.should be_success
      response.body.should =~ /Error/
    end

    it "should succeed given valid parameters" do
      params = { :type => "ideas", :response_type => "redis", :redis_key => "foo" }
      post_auth export_question_path(@question,  :format => 'xml'), params
      response.should be_success
      response.body.should =~ /Ok!/
    end
  end

  describe "GET 'show'" do
    before { @question = Factory.create(:aoi_question, :site => @api_user) }

    it "should succeed given no optional parameters" do
      get_auth question_path(@question)
      response.should be_success
      response.should have_tag "question", 1
      response.should have_tag "question id", @question.id.to_s
    end

    it "should correctly set optional parameters" do
      @visitor = Factory.create(:visitor, :site => @api_user)
      params = {
        :visitor_identifier => @visitor.identifier,
        :with_prompt => true,
        :with_appearance => true,
        :with_visitor_stats => true }
      get_auth question_path(@question), params
      response.should be_success
      response.should have_tag "question", 1
      response.should have_tag "question id", @question.id.to_s
      response.should have_tag "question picked_prompt_id"
      response.should have_tag "question appearance_id"
      response.should have_tag "question visitor_votes"
      response.should have_tag "question visitor_ideas"
    end

    it "should fail if 'with_prompt' is set but 'visitor_identifier' not provided" do
      pending("figure out argument dependencies") do
        params = { :with_prompt => true }
        get_auth question_path(@question), params
        response.should_not be_success
      end
    end

    it "should fail when trying to view other sites' questions" do
      other_user = Factory(:email_confirmed_user)
      get_auth other_user, question_path(@question)
      response.should_not be_success
    end
  end

  describe "PUT 'update'" do
    before { @question = Factory.create(:aoi_question, :site => @api_user) }

    it "should succeed give valid attributes" do
      params = {
        :question => {
          :active => false,
          :information => "foo",
          :name => "bar",
          :local_identifier => "baz" } }
      put_auth question_path(@question), params
      response.should be_success
    end

    it "should not be able to change the site id" do
      original_site_id = @question.site_id
      params = { :question => { :site_id => -1 } }
      put_auth question_path(@question), params
      @question.reload.site_id.should == original_site_id
    end

    it "should ignore protected attributes" do
        params = { :question => { :votes_count => 999 } }
        put_auth question_path(@question), params
        response.should be_success
        @question.reload.votes_count.should_not == 999
    end

    it "should fail when updating another site's question" do
      other_user = Factory(:email_confirmed_user) 
      params = { :question => { :name => "foo" } }
      put_auth other_user, question_path(@question), params
      response.should_not be_success
    end


  end

  describe "GET 'all_object_info_totals_by_date'" do
  end

  describe "GET 'object_info_totals_by_date'" do
  end

end
