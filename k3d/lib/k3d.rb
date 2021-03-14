begin
  $gtk.ffi_misc.gtk_dlopen("k3d")
  include FFI::K3d
  $cext = true
  puts "Using CExt version of K3d"
rescue
  $cext = false
  puts "Using pure Ruby version of K3d"
end

class Obj3
  def initialize
    @points = []
    @lines = []
  end

  def serialize
    { points: @points, lines: @lines }
  end

  def inspect
    serialize.to_s
  end

  def to_s
    serialize.to_s
  end

  attr_accessor :points, :lines

  def add_point *args
    case args.size
    when 1
      if args[0].is_a? Vec3
        @points.append args[0].arr
      elsif args[0].is_a? Array
        @points.append args[0]
      end
    when 3
      @points.append args
    end
  end

  def add_point_unique *args
    case args.size
    when 1
      if args[0].is_a? Vec3
        arr = args[0].arr
        unless @points.include? arr
          @points.append arr
          return true
        end
      elsif args[0].is_a? Array
        unless @points.include? args[0]
          @points.append args[0]
          return true
        end
      end
    when 3
      unless @points.include? args
        @points.append args
        return true
      end
    end
    return false
  end

  def find_point_index *args
    case args.size
    when 1
      # assume it is an array or a Vec3
      vec = *args[0]
    when 3
      # assume it is x, y, z
      vec = args
    end

    @points.find_index(vec)
  end

  def add_line idx1, idx2
    @lines.append([idx1, idx2])
  end

  def add_line_unique idx1, idx2
    unless @lines.include? [idx1, idx2]
      @lines.append [idx1, idx2]
    end
  end

  def find_line_index idx1, idx2
    @lines.find_index [idx1, idx2]
  end

  def rotate rot_mat
    ret_obj = Obj3.new
    ret_obj.lines = @lines
    ret_obj.points = matmul(rot_mat, @points.transpose).transpose
    ret_obj
  end

  def translate *args
    case args.size
    when 1
      vec = *args[0]
    when 3
      vec = args
    end

    ret_obj = Obj3.new
    ret_obj.lines = @lines
    ret_obj.points = @points.collect { |pt| pt.zip(vec).collect { |pv, vv| pv + vv } }
    ret_obj
  end

  def bounds
    pts = @points.compact
    x_bounds = pts.minmax { |a, b| a[0] <=> b[0] }
    y_bounds = pts.minmax { |a, b| a[1] <=> b[1] }
    z_bounds = pts.minmax { |a, b| a[2] <=> b[2] }

    return [x_bounds[0], y_bounds[0], z_bounds[0]], [x_bounds[1], y_bounds[1], z_bounds[1]]
  end
end

class DispObj2
  attr_accessor :points, :lines

  def display args
    @lines.each do |idx1, idx2|
      p1 = @points[idx1]
      p2 = @points[idx2]
      if p1.nil? or p2.nil?
        next
      end
      args.outputs.lines << {
        x: p1[0], y: p1[1],
        x2: p2[0], y2: p2[1]
      }
    end
  end
end

class Vec3
  def initialize x, y, z
    @arr = [x, y, z]
  end

  attr_accessor :arr

  def serialize
    { arr: @arr }
  end

  def inspect
    serialize.to_s
  end

  def to_s
    serialize.to_s
  end

  def x
    @arr[0]
  end

  def x= x
    @arr[0] = x
  end

  def y
    @arr[1]
  end

  def y= y
    @arr[1] = y
  end

  def z
    @arr[2]
  end

  def z= z
    @arr[2] = z
  end

  def * other
    if other.is_a? Vec3
      return Vec3.new x * other.x, y * other.y, z * other.z
    end
    raise TypeError,
          "Multiplication between unsupported types. expected Numeric or Vec3 but received #{other.class}"
  end

  def / other
    if other.is_a? Numeric
      return Vec3.new x / other, y / other, z / other
    elsif other.is_a? Vec3
      return Vec3.new x / other.x, y / other.y, z / other.z
    end
    raise TypeError,
          "Division between unsupported types. expected Numeric or Vec3 but received #{other.class}"
  end

  def mag
    return Math::sqrt(x * x + y * y + z * z)
  end

  def to_a
    return @arr
  end

  def coerce other
    if other.is_a? Numeric
      return Vec3.new(other, other, other), self
    elsif other.is_a? Array and other.size == 3
      return Vec3.new(other[0], other[1], other[2]), self
    end
  end
end

### matrix methods

def create_cext_mat mat
  num_items = mat.size * mat[0].size
  cmat = c_create_mat mat.size, mat[0].size
  mat.flatten.each_with_index do |v, idx|
    cmat[idx] = v.to_f
  end
  cmat
end

def cext_mat_to_rb cmat, width, height
  height.times.collect do |i|
    width.times.collect do |j|
      cmat[i * width + j]
    end
  end
end

def matmul mat1, mat2
  if $cext
    if mat1.class == FFI::K3d::FloatPointer
      cmat1 = mat1
    else
      cmat1 = create_cext_mat mat1
    end
    if mat2.class == FFI::K3d::FloatPointer
      cmat2 = mat2
    else
      cmat2 = create_cext_mat mat2
    end
    result = c_matmul(cmat1, mat1[0].size, mat1.size, cmat2, mat2[0].size, mat2.size)
    c_free_mat(cmat1)
    c_free_mat(cmat2)
    rb_result = cext_mat_to_rb(result, mat2[0].size, mat1.size)
    c_free_mat(result)
    return rb_result
  else
    return mat1.collect do |row1|
      mat2.transpose.collect do |col1|
        col1.zip(row1).inject(0) do |sum, pair|
          sum + pair[0] * pair[1]
        end
      end
    end
  end
end

### 3d helpers

def read_stl stl_filename
  f = $gtk.read_file(stl_filename)
  curr_chunk = []
  obj = Obj3.new
  show = true
  f.each_line do |line|
    stripped = line.strip
    if stripped == 'outer loop'
      curr_chunk = []
    elsif stripped.split(' ')[0] == 'vertex'
      verts = stripped.split(' ')[1..-1].collect { |f_str| f_str.to_f }
      curr_chunk.append(Vec3.new(verts[0], verts[1], verts[2]))
    elsif stripped == 'endloop'
      indicies = curr_chunk.collect do |vec|
        idx = obj.find_point_index vec
        if idx.nil?
          obj.add_point(vec)
          next obj.points.size() - 1
        end
        next idx
      end
      indicies.combination(2).each do |idx1, idx2|
        obj.add_line_unique(idx1, idx2)
      end
    end
  end

  obj
end

def ypr_rotation_mat yaw, pitch, roll
  ca = Math::cos yaw
  sa = Math::sin yaw

  cb = Math::cos pitch
  sb = Math::sin pitch

  cc = Math::cos roll
  sc = Math::sin roll

  [[ca * cb,  ca * sb * sc - sa * cc,  ca * sb * cc + sa * sc],
   [sa * cb,  sa * sb * sc + ca * cc,  sa * sb * cc - ca * sc],
   [    -sb,                 cb * sc,                 cb * cc]]
end

def axis_angle_mat axis, angle
  # note: requires axis to be a unit vector!
  c = Math::cos angle
  s = Math::sin angle
  diffc = 1 - c
  ux, uy, uz = *axis

  [[     c + ux * ux * diffc,  ux * uy * diffc - uz * s,  ux * uz * diffc + uy * s],
   [uy * ux * diffc + uz * s,       c + uy * uy * diffc,  uy * uz * diffc - ux * s],
   [uz * ux * diffc - uy * s,  uz * uy * diffc + ux * s,       c + uz * uz * diffc]]
end

def camera_projection args, obj, sensor_dist
  disp_obj = DispObj2.new
  disp_obj.points = obj.points.collect do |pt|
    if pt[2] > 0
      ratio = sensor_dist / pt[2]
      [ratio * pt[0] + args.grid.w_half, ratio * pt[1] + args.grid.h_half]
    end
  end
  disp_obj.lines = obj.lines
  disp_obj
end
