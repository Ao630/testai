require 'bundler/setup'
Bundler.require

ActiveRecord::Base.establish_connection

class User < ActiveRecord::Base
  has_secure_password
  validates :name, presence: true
  has_many :files
  has_many :words
end

class Word < ActiveRecord::Base
  belongs_to :user
end

class Folder < ActiveRecord::Base
  has_many :words
end