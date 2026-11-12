# Static catalogue of Shop subcategories for the demo. A real storefront would
# back this with a table; the experiment only needs one offer-results page.
class Subcategory
  Entry = Data.define(:slug, :name, :category, :blurb)

  ALL = [
    Entry.new(
      slug: "laptops-and-tablets",
      name: "Laptops & Tablets",
      category: "Electronics",
      blurb: "Member-only savings on laptops, tablets, and the gear that goes with them."
    )
  ].freeze

  def self.all = ALL
  def self.default = ALL.first
  def self.find(slug) = ALL.find { |entry| entry.slug == slug.to_s }
end
