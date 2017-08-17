class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.find_all_by!(key, value)
    value = Array.wrap(value)

    results = self.where(key => value).to_a
    unless results.size == value.size
      missing = value - results.map(&key)
      raise RuntimeError.new("Cannot find #{self.name}(s) with #{key}(s) [#{missing.join(', ')}]")
    end
    results
  end
end
