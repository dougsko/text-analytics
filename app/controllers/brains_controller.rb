class BrainsController < ApplicationController
    http_basic_authenticate_with :name => "boomi", :password => "b00m1"
  
  # GET /brains
  # GET /brains.json
  def index
    @brains = Brain.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @brains }
    end
  end

  # GET /brains/1
  # GET /brains/1.json
  def show
    @brain = Brain.find(params[:id])
    @classifier = Marshal.load(@brain.classifier)

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @brain }
    end
  end

  # GET /brains/new
  # GET /brains/new.json
  def new
    @brain = Brain.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @brain }
    end
  end

  # GET /brains/1/edit
  def edit
    @brain = Brain.find(params[:id])
  end

  # POST /brains
  # POST /brains.json
  def create
    @brain = Brain.new(params[:brain])
    if @brain.classifier_type == 'LSI'
        lsi = Classifier::LSI.new
        @brain.classifier = Marshal.dump lsi
    elsif @brain.classifier_type == 'Bayes'
        storage = Ankusa::MemoryStorage.new
        bayes = Ankusa::NaiveBayesClassifier.new storage
        @brain.classifier = Marshal.dump bayes
    end

    respond_to do |format|
      if @brain.save
        format.html { redirect_to @brain, notice: 'Brain was successfully created.' }
        format.json { render json: @brain, status: :created, location: @brain }
      else
        format.html { render action: "new" }
        format.json { render json: @brain.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /brains/1
  # PUT /brains/1.json
  def update
    @brain = Brain.find(params[:id])

    respond_to do |format|
      if @brain.update_attributes(params[:brain])
        format.html { redirect_to @brain, notice: 'Brain was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @brain.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /brains/1
  # DELETE /brains/1.json
  def destroy
    @brain = Brain.find(params[:id])
    @brain.destroy

    respond_to do |format|
      format.html { redirect_to brains_url }
      format.json { head :no_content }
    end
  end

  # POST /brains/:id/classify?text="classify me"
  def classify
      # xml
      if params[:phrase]
          text = params[:phrase][:text]
      elsif params[:text]
          text = params[:text]
      end
      @brain = Brain.find(params[:id])
      classifier = Marshal.load(@brain.classifier)
      @res = classifier.classify(params[:text])
      respond_to do |format|
          format.html { 
              flash[:notice] = @res
              redirect_to @brain
          }
          format.xml { render :locals => {:res => @res} } #classify.xml.builder
      end
  end

  # POST /brains/:id/train?text="stuff"&category="category"
  def train
      # xml
      if params[:phrase]
          text = params[:phrase][:text]
          category = params[:phrase][:category]
      # cgi
      elsif params[:text]
          text = params[:text]
          category = params[:category]
      end
      @brain = Brain.find(params[:id])
      classifier = Marshal.load(@brain.classifier)
      if @brain.classifier_type == 'Bayes'
          classifier.train(category, text)
          @brain.classifier = Marshal.dump(classifier)
      else
        classifier.add_item(text, category)
        classifier.build_index if classifier.needs_rebuild?
        @brain.classifier = Marshal.dump(classifier)
      end
      respond_to do |format|
          if @brain.save
              @res = "success"
              format.html { redirect_to @brain, notice: 'Item successfully added.' }
              format.xml { render :locals => {:res => @res} }
          end
      end
  end

  # POST /brains/:id/related?text="stuff"
  def related
      # xml
      if params[:phrase]
          text = params[:phrase][:text]
          brain_id = params[:phrase][:brain_id]
      elsif params[:text]
          text = params[:text]
          brain_id = params[:id]
      end
      @brain = Brain.find(brain_id)
      classifier = Marshal.load(@brain.classifier)
      if @brain.classifier_type == 'LSI'
          @res = classifier.find_related(text)
      else
          @res = "Only the LSI classifier supports this function."
      end
      respond_to do |format|
          format.xml { render :locals => {:res => @res} }
      end
  end


  # POST /brains/:name/delete_item/:item_index
  def delete_item
    @brain = Brain.where(:name => params[:name]).first
    classifier = YAML.load(@brain.classifier)
    classifier.remove_item(classifier.items[params[:item_index].to_i])
    classifier.build_index if classifier.needs_rebuild?
    @brain.classifier = YAML.dump(classifier)
    respond_to do |format|
        if @brain.save
            format.html { redirect_to @brain, notice: 'Item successfully deleted.' }
        end
    end
  end
end
