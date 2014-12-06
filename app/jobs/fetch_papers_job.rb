require 'fileutils'

class FetchPapersJob
  class << self
    # enables definition of @state, @scraper in child classes
    attr_accessor :state, :scraper
  end

  def perform(legislative_term)
    setup(legislative_term)
  end

  def setup(legislative_term) # FIXME
    fail 'State is not defined' unless defined?(self.class.state) && !self.class.state.blank?
    @body = Body.find_by(state: self.class.state)
    fail 'Required body "' + self.class.state + '" not found' if @body.nil?
    fail 'Legislative term is empty' if legislative_term.nil?
    @legislative_term = legislative_term
  end

  def ensure_scraper!
    fail 'scraper is not defined' unless defined?(self.class.scraper) && !self.class.scraper.blank?
    self.class.scraper::Overview.new(@legislative_term)
  end

  def import_new_papers
    scraper = ensure_scraper!
    page = 1
    found_new_paper = false
    loop do
      found_new_paper = false
      scraper.scrape(page).each do |item|
        found_new_paper = true if import_paper(item)
      end
      page += 1
      break unless found_new_paper
    end
  end

  def import_all_papers
    ensure_scraper!
    scraper = self.class.scraper::Overview.new(@legislative_term)
    i = 0
    scraper.scrape_all.each do |item|
      Rails.logger.debug "[import_all_papers] item #{i += 1}: #{item[:full_reference]}"
      import_paper(item)
    end
  end

  def download_papers
    @papers = Paper.where(body: @body, downloaded_at: nil).limit(50)
    session = patron_session
    @papers.find_each do |paper|
      Rails.logger.debug "[download_papers] #{@body.state} #{paper.full_reference}"
      download_paper(paper, session)
      store_paper(paper)
    end
  end

  def patron_session
    sess = Patron::Session.new
    # sess.timeout = 15
    sess.headers['User-Agent'] = Rails.application.config.user_agent
    sess
  end

  def download_paper(paper, session = nil)
    session ||= patron_session
    filepath = paper.local_path
    folder = filepath.dirname
    FileUtils.mkdir_p folder

    resp = session.get(paper.url)
    if resp.status != 200
      Rails.logger.debug "Download failed for Paper #{paper.reference}"
      return
    end

    f = File.open(filepath, 'wb')
    begin
      f.write(resp.body)
    rescue
      Rails.logger.debug "Cannot write file for Paper #{paper.reference}"
      return
    ensure
      f.close if f
    end

    return unless paper.downloaded_at.nil?
    paper.downloaded_at = DateTime.now
    paper.save
  end

  def store_paper(paper)
    return false unless FogStorageBucket.files.head(paper.path).nil?
    local_path = get_or_download_pdf(paper)
    file = FogStorageBucket.files.new(key: paper.path, public: true, body: File.open(local_path))
    file.save
  end

  def extract_text_from_papers
    @papers = Paper.where(body: @body, contents: nil).where.not(downloaded_at: nil)

    @papers.find_each do |paper|
      get_or_download_pdf(paper)
      Rails.logger.info "Extracting text from [#{paper.reference}] \"#{paper.title}\""
      text = paper.extract_text
      paper.contents = text
      paper.save
    end
  end

  def count_page_numbers
    @papers = Paper.where(body: @body, page_count: nil).where.not(downloaded_at: nil)

    @papers.find_each do |paper|
      get_or_download_pdf(paper)
      Rails.logger.info "Counting pages in [#{paper.reference}] \"#{paper.title}\""
      count = paper.extract_page_count
      paper.page_count = count
      paper.save
    end
  end

  def get_or_download_pdf(paper)
    download_paper(paper) unless File.exist? paper.local_path
    paper.local_path
  end
end