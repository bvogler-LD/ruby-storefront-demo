# Idempotent seed data: one demo user and 60 fictional offers.
# All merchants, products, and discounts are invented for this demo.

User.find_or_create_by!(public_id: User::DEMO_PUBLIC_ID) do |user|
  user.display_name = "Demo Shopper"
end

merchants = [
  "Northwind Computing", "Bluepeak Electronics", "Larkspur Devices", "Copperline Tech",
  "Meridian Laptops", "Fernhill Digital", "Quillon Systems", "Harborlight Gadgets",
  "Tessera Mobile", "Ashgrove Audio", "Pinecrest PCs", "Solstice Screens"
]

products = [
  [ "14-inch ultralight laptop", "A 2.6 lb everyday laptop with an all-day battery and a matte display." ],
  [ "11-inch tablet with keyboard folio", "A note-taking tablet bundled with a detachable keyboard cover." ],
  [ "16-inch creator laptop", "A colour-accurate screen and dedicated graphics for photo and video work." ],
  [ "2-in-1 convertible laptop", "Folds flat into a tablet, with an active pen included in the box." ],
  [ "Student laptop bundle", "A durable 13-inch laptop with a sleeve and wireless mouse." ],
  [ "8-inch reading tablet", "A pocketable tablet tuned for books, comics, and long flights." ],
  [ "Gaming laptop, 15-inch", "A high-refresh display and a cooling design that stays quiet." ],
  [ "Refurbished business laptop", "Certified refurbished with a one-year warranty and a new battery." ],
  [ "Tablet stylus and case set", "A pressure-sensitive stylus with a magnetic folio case." ],
  [ "USB-C docking station", "One cable for two monitors, wired network, and charging." ],
  [ "Laptop backpack, 17-inch", "A water-resistant pack with a padded device sleeve." ],
  [ "Extended protection plan", "Three years of accidental-damage cover for a new laptop or tablet." ]
]

discounts = [
  "15% off", "$100 off", "20% off sitewide", "10% cash back", "$50 off $500+",
  "25% off accessories", "Free 2-day shipping", "12% off", "$75 off", "Up to 30% off"
]

slug = Subcategory.default.slug

60.times do |index|
  position = index + 1
  merchant = merchants[index % merchants.size]
  name, description = products[(index * 5) % products.size]

  Offer.find_or_initialize_by(subcategory_slug: slug, position: position).update!(
    merchant: merchant,
    title: "#{merchant}: #{name}",
    description: description,
    discount_text: discounts[(index * 3) % discounts.size],
    hue: (index * 47) % 360
  )
end

puts "Seeded #{User.count} demo user and #{Offer.count} offers."
