require 'roo'
#
# == Schema Information
#
# Table name: images
#
#  id                 :integer          not null, primary key
#  path               :string(255)
#  website_id         :integer
#  group_id           :integer
#  created_at         :datetime
#  updated_at         :datetime
#  canonical_id       :string(255)
#  assignments_count  :integer          default(0)
#  descriptions_count :integer          default(0)
#  title              :text(65535)
#  priority           :boolean          default(FALSE)
#  status_code        :integer          default(0)
#  page_urls          :text(65535)
#
# Indexes
#
#  index_images_on_group_id    (group_id)
#  index_images_on_website_id  (website_id)
#

class Image < ActiveRecord::Base
  serialize :page_urls, JSON

  acts_as_taggable_on :tags
  before_validation :update_status_code

  belongs_to :website, touch: true
  belongs_to :group, touch: true

  has_many :descriptions, dependent: :destroy
  has_associated_audits
  has_many :assignments, dependent: :destroy
  has_many :users, through: :assignments

  validates :path, :presence => true, :uniqueness => {:scope => :website_id}
  validates :canonical_id, :presence => true, :uniqueness => {:scope => :website_id}
  validates_associated :website, :group
  validates_presence_of :website, :group

  default_scope {order('priority DESC, created_at DESC')}

  scope :unassigned, -> (n = 0) { select { |i| i.assignments_count == n } }
  scope :undescribed, -> (n = 0) { select { |i| i.descriptions_count == n } }
  scope :assigned_undescribed, -> (n = 0) { select { |i| i.descriptions_count == n && i.assignments_count > n} }
  scope :unassigned_undescribed, -> (n = 0) { select { |i| i.descriptions_count == n && i.assignments_count == n} }
  scope :described, -> (n = 0) { select { |i| i.descriptions_count > n } }
  scope :assigned, -> (n = 0) { select { |i| i.assignments_count > n } }
  scope :prioritized, -> { order('priority DESC')}

  paginates_per 50

  def to_s
    path
  end

  def alt(status_ids=[2])
    d = descriptions.where(metum_id: 1, status_id: status_ids, locale: "en").first
    if d
      d.text
    else
      ""
    end
  end

  def long(status_ids=[2])
    d = descriptions.where(metum_id: 3, status_id: status_ids, locale: "en").first
    if d
      d.text 
    else
      ""
    end
  end

  def is_mca?
    if website.url.include?("mcachicago")
      true
    else 
      false
    end
  end


  def url
    if website
      website.url + path
    end
  end

  #TODO per locale
  #has no descriptions by this user 
  def undescribed_by?(user)
    !descriptions.collect{ |d| d.user_id}.compact.include?(user.id)
  end

  #has 1 of description by this user
  def described_by?(user)
   descriptions.collect{ |d| d.user_id}.compact.include?(user.id)
  end

  #TODO consider locale
  #has 1 of each metum by this user  ? in any combo of locales and status'es
  def completed_by?(user)
    meta_ids = Metum.all.map{|m| m.id}
    described_meta_ids = descriptions.collect{ |d| d.metum_id if d.user_id == user.id}.compact 
    (meta_ids - described_meta_ids).empty?
  end

  def status
    case status_code
    when 0
      "Not Described"
    when 1
      "Partially Completed"
    when 2
      "Ready to Review" 
    when 3
      "Completed" 
    else
      return "Not Described"
    end
  end

  def begun?
    descriptions.count > 0
  end

  def ready_to_review?
    meta_ids = Metum.all.map{|m| m.id}
    if meta_ids.count == (descriptions.approved +  descriptions.ready_to_review).map{|d| d.metum_id unless d.nil?  }.uniq.compact.count
      true
    else
      false
    end
  end

  #completed all meta in any combo of locales
  def completed?
    meta_ids = Metum.all.map{|m| m.id}
    if meta_ids.count == descriptions.approved.map{|d| d.metum_id unless d.nil?}.uniq.compact.count
      true
    else
      false
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)
    puts "YAML:"
    puts spreadsheet.to_yaml #DEBUG
    header = spreadsheet.row(1)
    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      image = find_by_id(row["id"]) || new
      #image.attributes = row.to_hash.slice(*accessible_attributes)
      image.attributes = row.to_hash
      image.save!
    end
  end

  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)
    when ".csv" then Roo::CSV.new(file.path)
    when ".xls" then Roo::Excel.new(file.path)
    when ".xlsx" then Roo::Excelx.new(file.pat)
    else raise "Unknown file type: #{file.original_filename}"
    end
  end

  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      csv << column_names
      all.each do |product|
        csv << product.attributes.values_at(*column_names)
      end
    end
  end

  def update_status_code
    if begun? 
      if completed?
        self.status_code = 3
      elsif ready_to_review?
        self.status_code = 2
      else
        self.status_code = 1
      end
    else
      self.status_code = 0
    end
    return true
  end
end
