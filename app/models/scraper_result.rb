class ScraperResult < ApplicationRecord
  belongs_to :body

  def status
    if queued?
      'waiting'
    elsif success?
      'success'
    elsif running?
      'running'
    else
      'failure'
    end
  end

  def queued?
    !created_at.nil? && started_at.nil? && stopped_at.nil?
  end

  def running?
    !started_at.nil? && stopped_at.nil?
  end

  def got_new_papers?
    !new_papers.nil? && new_papers > 0
  end

  def instant?
    !scraper_class.blank? && scraper_class.include?('Instant')
  end

  def to_param
    self.class.hashids.encode(id)
  end

  def self.find_by_hash(hash)
    id = hashids.decode(hash).first
    fail 'Invalid id' if id.nil?
    find(id)
  end

  def self.hashids
    Hashids.new('ScraperResult', 5)
  end

  def as_json(*options)
    super(*options).merge(status: status, running: running?, id: to_param, instant: instant?)
  end
end
