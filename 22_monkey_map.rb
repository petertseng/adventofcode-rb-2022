def contiguous(arr, x)
  chunks = arr.chunk(&:itself).to_a
  case chunks.size
  when 3
    raise "bad chunks #{chunks}" if chunks.map { |c| c[0] == x } != [false, true, false]
    chunks[1][1].size
  when 2
    raise "bad chunks #{chunks}" if chunks.map { |c| c[0] == x } != [true, false]
    chunks[0][1].size
  when 1
    # Return nil instead of 0 to make it obvious when something is improperly used.
    chunks[0][0] == x ? chunks[0][1].size : nil
  else raise "bad chunks #{chunks}"
  end
end

map = ARGF.take_while { |l| !l.chomp.empty? }.map { |l| l.chomp.freeze }.freeze
dirs = ARGF.readline.chomp.chars.slice_when { |a, b| 'LR'.include?(a) || 'LR'.include?(b) }.map { |dir|
  dir == %w(L) || dir == %w(R) ? dir[0].freeze : Integer(dir.join)
}.freeze

max_width = map.map(&:size).max

side_length = case map.size
when 200; 50
when 12; 4
else raise "unknown size #{map.size}"
end

# which faces exist?
face_exist = (0...6).map { |y|
  top = map[y * side_length]
  bottom = map[(y + 1) * side_length - 1]
  raise "map inconsistently exists or not for #{y}" if top.nil? != bottom.nil?
  next Array.new(6, false).freeze unless top
  (0...6).map { |x|
    top_left = top[x * side_length]
    top_right = top[(x + 1) * side_length - 1]
    bottom_left = bottom[x * side_length]
    bottom_right = bottom[(x + 1) * side_length - 1]
    raise "map inconsistently exists or not for #{y} #{x}" if [top_left, top_right, bottom_left, bottom_right].map { |c| c.nil? || c == ' ' }.uniq.size != 1
    %w(. #).include?(top_left)
  }.freeze
}.freeze
# How wide is the map, in multiples of the side length, per row?
row_width = face_exist.map { |r| contiguous(r, true) }.freeze
# How tall is the map, in multiples of the side length, per column?
col_height = face_exist.transpose.map { |r| contiguous(r, true) }.freeze

[false, true].each { |cube|
  y = 0
  x = map[0].index(?.)
  dy = 0
  dx = 1

  if cube
    left_conn = {}
    right_conn = {}
    up_conn = {}
    down_conn = {}

    reverse_dir = ->conn {
      # need object_id because the four are indistinguishable when they're all {}
      case conn.object_id
      when left_conn.object_id; [0, 1]
      when right_conn.object_id; [0, -1]
      when up_conn.object_id; [1, 0]
      when down_conn.object_id; [-1, 0]
      else raise "#{conn} not valid connection"
      end
    }

    connect = ->(inconn, inys, inxs, outconn, outys, outxs, also_reverse: true) {
      outdy, outdx = reverse_dir[outconn]
      Array(inys).product(Array(inxs)).zip(Array(outys).product(Array(outxs))) { |(iny, inx), (outy, outx)|
        raise "duplicate conn #{iny} #{inx}" if inconn.has_key?(iny * max_width + inx)
        inconn[iny * max_width + inx] = [outy, outx, outdy, outdx].freeze
      }
      connect[outconn, outys, outxs, inconn, inys, inxs, also_reverse: false] if also_reverse
    }

    case side_length
    when 50
      # top of 1 and left of 6
      connect[up_conn, 0, 50...100, left_conn, 150...200, 0]
      # left of 1 and left of 4
      connect[left_conn, 0...50, 50, left_conn, 149.downto(100), 0]
      # top of 2 and bottom of 6
      connect[up_conn, 0, 100...150, down_conn, 199, 0...50]
      # bottom of 2 and right of 3
      connect[down_conn, 49, 100...150, right_conn, 50...100, 99]
      # right of 2 and right of 5
      connect[right_conn, 0...50, 149, right_conn, 149.downto(100), 99]
      # left of 3 and top of 4
      connect[left_conn, 50...100, 50, up_conn, 100, 0...50]
      # bottom of 5 and right of 6
      connect[down_conn, 149, 50...100, right_conn, 150...200, 49]
    when 4
      # Only these three connections are needed for the example:
      # right of 4 and top of 5
      connect[right_conn, 4...8, 11, up_conn, 8, 15.downto(12)]
      # bottom of 5 and bottom of 2
      connect[down_conn, 11, 8...12, down_conn, 7, 3.downto(0)]
      # top of 3 and left of 1
      connect[up_conn, 4, 4...8, left_conn, 0...4, 8]
      # I won't add the other four since they wouldn't get tested,
      # so there's no way to know whether I got them right.
      # Better to not have code at all than untested potentially-incorrect code.
      # top of 1 and top of 2
      # right of 1 and right of 6
      # left of 2 and bottom of 6
      # bottom of 3 and left of 5
    else raise "unknown side length #{side_length}"
    end
  end

  dirs.each { |dir|
    case dir
    when ?L; dy, dx = -dx, dy
    when ?R; dy, dx = dx, -dy
    when Integer
      dir.times {
        ny = y + dy
        nx = x + dx
        ndy = dy
        ndx = dx

        if dy > 0 && ny % side_length == 0 && (!map[ny] || !map[ny][nx] || map[ny][nx] == ' ')
          if cube
            ny, nx, ndy, ndx = down_conn.fetch(y * max_width + x)
          else
            ny -= col_height[x / side_length] * side_length
          end
        elsif dy < 0 && y % side_length == 0 && (ny < 0 || !map[ny] || !map[ny][nx] || map[ny][nx] == ' ')
          if cube
            ny, nx, ndy, ndx = up_conn.fetch(y * max_width + x)
          else
            ny += col_height[x / side_length] * side_length
          end
        elsif dx > 0 && nx % side_length == 0 && (!map[ny][nx] || map[ny][nx] == ' ')
          if cube
            ny, nx, ndy, ndx = right_conn.fetch(y * max_width + x)
          else
            nx -= row_width[y / side_length] * side_length
          end
        elsif dx < 0 && x % side_length == 0 && (nx < 0 || !map[ny][nx] || map[ny][nx] == ' ')
          if cube
            ny, nx, ndy, ndx = left_conn.fetch(y * max_width + x)
          else
            nx += row_width[y / side_length] * side_length
          end
        end

        #raise "moved into nowhere #{ny} #{nx} from #{y} #{x} facing #{dy} #{dx}" if ny < 0 || nx < 0 || !map[ny] || !map[ny][nx] || map[ny][nx] == ' '
        break if map[ny][nx] == ?#
        y = ny
        x = nx
        dy = ndy
        dx = ndx
        #raise "moving not straight #{dy} #{dx}" unless dy == 0 || dx == 0
        #puts "Moved to #{y} #{x} facing #{dy} #{dx}"
      }
    else raise "bad dir #{dir}"
    end
  }

  puts (y + 1) * 1000 + (x + 1) * 4 + ([[0, 1], [1, 0], [0, -1], [-1, 0]].index([dy, dx]) || (raise "#{dy} #{dx} isn't valid facing"))
}
