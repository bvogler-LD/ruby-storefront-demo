module OffersHelper
  # Self-contained SVG placeholder so the demo needs no external images.
  def offer_placeholder(offer)
    initials = offer.merchant.split.map { |word| word[0] }.first(2).join.upcase
    hue = offer.hue

    tag.svg(class: "offer-card__image", viewBox: "0 0 320 180", role: "img",
            "aria-label": "#{offer.merchant} placeholder image", preserveAspectRatio: "xMidYMid slice") do
      safe_join([
        tag.rect(width: 320, height: 180, fill: "hsl(#{hue} 55% 88%)"),
        tag.circle(cx: 262, cy: 34, r: 70, fill: "hsl(#{(hue + 30) % 360} 60% 80%)"),
        tag.circle(cx: 40, cy: 170, r: 56, fill: "hsl(#{(hue + 330) % 360} 55% 82%)"),
        tag.text(initials, x: 160, y: 104, "text-anchor": "middle", "font-size": 46, "font-weight": 700,
                           "font-family": "system-ui, sans-serif", fill: "hsl(#{hue} 45% 30%)")
      ])
    end
  end

  # Window of page numbers around the current page.
  def page_window(current, total, radius: 2)
    ([ 1, total ] + ((current - radius)..(current + radius)).to_a).select { |n| n.between?(1, total) }.uniq.sort
  end
end
