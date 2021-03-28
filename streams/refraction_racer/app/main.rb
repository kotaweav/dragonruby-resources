def tick args
  if args.state.tick_count == 0
    render_spaceship args
    setup args
  end

  process_inputs args
  update_state args
  display args
end

def setup args
  args.state.spaceship.pos = Vec2.new(500, 400)
  args.state.spaceship.orient = 0 # radians
  args.state.spaceship.vel = Vec2.new(0, 0)
  args.state.spaceship.max_angular_vel = Math::PI / 40
  args.state.spaceship.mass = 5 # kg
  args.state.spaceship.force = 0
  args.state.spaceship.max_force = 500

  args.state.polygons = [
    Polygon.new(
      [
        Vec2.new(300, 300),
        Vec2.new(500, 300),
        Vec2.new(400, 600)
      ]
    )
  ]
end

def process_inputs args
  args.state.spaceship.orient -=
    args.state.spaceship.max_angular_vel * args.inputs.keyboard.left_right

  args.state.spaceship.force =
    args.inputs.keyboard.up ? args.state.spaceship.max_force : 0

  if args.inputs.keyboard.key_down.backspace
    $gtk.reset
  end
end

def update_state args
  dt = 1 / 60

  orientation = Vec2.new Math::cos(args.state.spaceship.orient),
                         Math::sin(args.state.spaceship.orient)
  acc_mag = args.state.spaceship.force / args.state.spaceship.mass
  acc = orientation * acc_mag
  args.state.spaceship.vel += acc * dt
  d_pos = args.state.spaceship.vel * dt

  args.state.polygons.each do |polygon|
    collisions = polygon.check_collision args.state.spaceship.pos, d_pos
    collisions.each do |pt, line|
      args.outputs.solids << {
        x: pt.x - 3, y: pt.y - 3, w: 6, h: 6, r: 255
      }

      diff_pts = line[0] - line[1]
      normal = Vec2.new(-diff_pts.y, diff_pts.x) / diff_pts.mag
      if normal.dot(d_pos) > 0
        normal = Vec2.new(diff_pts.y, -diff_pts.x) / diff_pts.mag
      end
      args.outputs.lines << {
        x: pt.x, y: pt.y, x2: (pt + normal * 20).x, y2: (pt + normal * 20).y
      }

      # REVISED FROM VIDEO: reduce the ior values
      ref = refraction args, d_pos, normal, 1, 1.3
      ref /= ref.mag
      args.outputs.lines << {
        x: pt.x, y: pt.y, x2: pt.x + 30 * ref.x, y2: pt.y + 30 * ref.y, b: 255, r: 0
      }

      # REVISED FROM VIDEO: previously was only changing d_pos.
      # should also adjust velocity
      args.state.spaceship.vel = ref * args.state.spaceship.vel.mag
      d_pos = ref * d_pos.mag
    end
  end

  args.state.spaceship.pos += d_pos
  args.state.spaceship.pos = Vec2.new args.state.spaceship.pos.x % args.grid.w,
                                      args.state.spaceship.pos.y % args.grid.h
end

def refraction args, input_vec, normal, n1, n2
  l = input_vec / input_vec.mag
  r = n1 / n2
  normal /= normal.mag
  c = (normal * -1).dot(l)
  radicand = 1 - r * r * (1 - c * c)
  if radicand < 0
    return input_vec
  end
  return l * r + normal * (r * c - Math::sqrt(1 - r * r * (1 - c * c)))
end

def display args
  args.outputs.sprites << {
    path: :spaceship,
    x: args.state.spaceship.pos.x - 20 / 2,
    y: args.state.spaceship.pos.y - 30 / 2, w: 30, h: 20,
    source_x: 0, source_y: 0, source_w: 30, source_h: 40,
    angle: args.state.spaceship.orient * 180 / Math::PI
  }

  args.state.polygons.each { |p| p.display args; p.display_debug args }
end

def render_spaceship args
  args.render_target(:spaceship).lines << [{
    x: 0, y: 0, x2: 30, y2: 20
  }, {
    x: 30, y: 20, x2: 0, y2: 40
  }, {
    x: 0, y: 40, x2: 10, y2: 20
  }, {
    x: 10, y: 20, x2: 0, y2: 0
  }]

  args.render_target(:spaceship).solids << {
    x: 10, y: 10, w: 10, h: 20
  }
end

class Volume
  def initialize polygon, ior
    @polygon = polygon
    @ior = ior
  end

  attr_accessor :polygon
  attr_accessor :ior
end

class Vec2
  def initialize x, y
    @x = x
    @y = y
  end

  attr_accessor :x, :y

  def + v
    if v.is_a? Vec2
      return Vec2.new @x + v.x, @y + v.y
    end
    return Vec2.new @x + v, @y + v
  end

  def - v
    if v.is_a? Vec2
      return Vec2.new @x - v.x, @y - v.y
    end
    return Vec2.new @x - v, @y - v
  end

  def * v
    if v.is_a? Vec2
      return Vec2.new @x * v.x, @y * v.y
    end
    return Vec2.new @x * v, @y * v
  end

  def / v
    if v.is_a? Vec2
      return Vec2.new @x / v.x, @y / v.y
    end
    return Vec2.new @x / v, @y / v
  end

  def cross v
    return @x * v.y - @y * v.x
  end

  def dot v
    return @x * v.x + @y * v.y
  end

  def mag
    return Math::sqrt(@x * @x + @y * @y)
  end

  def to_s
    return "(#{@x.round(2)}, #{@y.round(2)})"
  end
end

class Polygon
  def initialize pts=nil
    @pts = pts || []
  end

  attr_accessor :pts

  def add_point pt
    unless pt.is_a? Vec2
      raise "Not a Vec2!"
    end
    @pts.append(pt)
  end

  def check_collision pt, vec
    @pts.zip(@pts.rotate(1)).collect do |pp1, pp2|
      p = pp1
      r = (pp2 - pp1)

      q = pt
      s = vec

      intersect = compute_intersect(p, r, q, s)
      unless intersect.nil?
        next [intersect, [pp1, pp2]]
      end
    end.compact
  end

  def display args
    @pts.zip(@pts.rotate(1)) do |pp1, pp2|
      args.outputs.lines << {
        x: pp1.x, y: pp1.y, x2: pp2.x, y2: pp2.y
      }
    end
  end

  def display_debug args
    @pts.zip(@pts.rotate(1)) do |pp1, pp2|
      dpt = pp2 - pp1
      normal = Vec2.new(-dpt.y, dpt.x)
      normal /= normal.mag
      center_pt = (pp1 + pp2) / 2
      args.outputs.lines << {
        x: center_pt.x, y: center_pt.y,
        x2: center_pt.x + 10 * normal.x, y2: center_pt.y + 10 * normal.y,
        r: 200
      }
    end
  end
end

def test_check_collision args
  poly = Polygon.new
  poly.add_point Vec2.new 300, 300
  poly.add_point Vec2.new 500, 300
  poly.add_point Vec2.new 400, 600

  poly.display args

  collisions = poly.check_collision Vec2.new(200, 400), Vec2.new(300, 100)

  args.outputs.solids <<
    [{
       x: 197, y: 397, w: 6, h: 6
     },
     {
       x: 200 + 300 - 3, y: 400 + 100 - 3, w: 6, h: 6
     }]

  args.outputs.lines << { x: 200, y: 400, x2: 200 + 300, y2: 400 + 100 }

  collisions.each do |pt, line|
    args.outputs.solids <<
    { x: pt.x - 3, y: pt.y - 3, w: 6, h: 6, r: 255 }
  end
end

def compute_intersect p, r, q, s
  # taken from: https://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect/565282#565282
  t = (q - p).cross(s) / r.cross(s)
  u = (q - p).cross(r) / r.cross(s)

  if r.cross(s) != 0 and t > 0 && t < 1 && u > 0 && u < 1
    return p + r * t
  else
    return nil
  end
end
