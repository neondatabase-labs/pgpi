#!/usr/bin/env ruby
# elephantshark --no-bw | ./logs-to-svg.rb > ~/Downloads/eslog.svg

xmargin = 20
ymargin = 10
fontsize = 15
lineheight = 1.4
charwidth = 0.465 # for calculating svg width

w = 0
y = ymargin
lhpx = (fontsize * lineheight).ceil
text = []
ARGF.each do |raw|
  w = [w, raw.length].max
  y += lhpx
  line = raw.chomp
    .gsub(/[<>"']/, { '<' => '&lt;', '>' => '&gt;', '"' => '&quot;', "'" => '&apos;' })
    .gsub(/\033\[(\d+)m(.*?)\033\[0m/, '<tspan class="c\1">\2</tspan>')
  text << %{<text xml:space="preserve" x="#{xmargin}px" y="#{y}px">#{line}</text>} unless line.empty?
end

puts %{<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{(2 * xmargin + w * fontsize * charwidth).ceil}px #{2 * ymargin + y}px">
  <style><![CDATA[
    svg { background: #002050; }
    text { font: #{fontsize}px 'IBM Plex Mono', monospace; fill: #eee; }
    tspan.c33 { fill: #ffee00; }
    tspan.c35 { fill: #00dddd; }
    tspan.c36 { fill: #ff44ff; }
  ]]></style>
  #{text.join("\n  ")}
</svg>
}
