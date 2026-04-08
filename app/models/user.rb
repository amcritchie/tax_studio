class User < ApplicationRecord
  include Sluggable

  has_secure_password
  has_one_attached :avatar

  validates :email, presence: true, uniqueness: true

  before_save :set_name_parts, if: -> { name_changed? }

  def self.from_omniauth(auth)
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    user = find_by(email: auth.info.email)
    if user
      user.update!(provider: auth.provider, uid: auth.uid)
      return user
    end

    create!(
      email: auth.info.email,
      name: auth.info.name,
      provider: auth.provider,
      uid: auth.uid,
      password: SecureRandom.hex(16)
    )
  rescue ActiveRecord::RecordNotUnique
    find_by(email: auth.info.email) || find_by(provider: auth.provider, uid: auth.uid)
  end

  def display_name
    name.presence || email.split("@").first.capitalize
  end

  def admin?
    role == "admin"
  end

  def avatar_initials
    (name.presence || email.split("@").first).first.upcase
  end

  AVATAR_COLORS = %w[#EF4444 #F97316 #EAB308 #22C55E #06B6D4 #3B82F6 #8B5CF6 #EC4899].freeze

  def avatar_color
    key = name.presence || email
    AVATAR_COLORS[Digest::MD5.hexdigest(key).hex % AVATAR_COLORS.size]
  end

  private

  def set_name_parts
    parts = name.to_s.strip.split(" ")
    self.first_name = parts.first
    self.last_name = parts.last if parts.size > 1
  end

  def name_slug
    "#{name}-#{email}".downcase.gsub(/\s+/, "-")
  end
end
