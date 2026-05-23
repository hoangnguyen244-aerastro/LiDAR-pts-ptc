#!/usr/bin/env python3
# ptc_compress_with_rgb.py
# Nen file .pts -> .ptc (delta + RGB Huffman)

import sys, struct, heapq

def read_pts(filename):
    points = []
    colors = []
    with open(filename, 'r') as f:
        lines = f.readlines()
    if not lines:
        return points, colors
    first_line = lines[0].strip()
    first_parts = first_line.split()
    if len(first_parts) == 1 and first_parts[0].isdigit():
        start = 1
    else:
        start = 0
    for line in lines[start:]:
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) >= 6:
            x = float(parts[0]); y = float(parts[1]); z = float(parts[2])
            r = int(parts[3]); g = int(parts[4]); b = int(parts[5])
            points.append((x, y, z))
            colors.append((r, g, b))
    return points, colors

def huffman_encode(data):
    freq = {}
    for val in data:
        freq[val] = freq.get(val, 0) + 1
    heap = [[f, [s, ""]] for s, f in freq.items()]
    heapq.heapify(heap)
    while len(heap) > 1:
        lo = heapq.heappop(heap)
        hi = heapq.heappop(heap)
        for pair in lo[1:]:
            pair[1] = '0' + pair[1]
        for pair in hi[1:]:
            pair[1] = '1' + pair[1]
        heapq.heappush(heap, [lo[0]+hi[0]] + lo[1:] + hi[1:])
    code_map = {}
    for sym, code_str in heap[0][1:]:
        code_bits = [int(bit) for bit in code_str]
        code_map[sym] = (code_bits, code_str)
    return code_map

def encode_to_bits(data, code_map):
    bits = []
    for val in data:
        bits.extend(code_map[val][0])
    return bits

def bits_to_bytes(bits):
    nbits = len(bits)
    nbytes = (nbits + 7) // 8
    byte_arr = bytearray()
    for i in range(0, nbits, 8):
        byte = 0
        for j in range(8):
            if i+j < nbits and bits[i+j]:
                byte |= (1 << (7-j))
        byte_arr.append(byte)
    return nbits, nbytes, byte_arr

def write_ptc(filename, N, s, offset, delta_bits, delta_code_map, rgb_bits, rgb_code_map):
    with open(filename, 'wb') as f:
        f.write(b'PTC_FORMAT_V1\nHEADER_START\n')
        f.write(f'num_points: {N}\n'.encode())
        f.write(b'has_color: TRUE\n')
        f.write(f'scale_factor: {s:.10f}\n'.encode())
        f.write(f'offset: {offset[0]:.6f} {offset[1]:.6f} {offset[2]:.6f}\n'.encode())
        f.write(b'point_type: int32\ncolor_space: RGB\n')
        f.write(b'compression_method: DELTA_HUFFMAN_WITH_RGB\nchecksum: 00000000\nHEADER_END\n')
        f.write(b'BINARY_DATA_START\n')
        f.write(struct.pack('<I', N))

        # Delta Huffman dictionary
        f.write(b'DELTA_HUFFMAN_DICT_START\n')
        f.write(f'{len(delta_code_map)}\n'.encode())
        for sym, (code_bits, code_str) in delta_code_map.items():
            f.write(f'{sym} {len(code_bits)} {code_str}\n'.encode())
        f.write(b'DELTA_HUFFMAN_DICT_END\n')
        # Delta bitstream
        nbits, nbytes, byte_arr = bits_to_bytes(delta_bits)
        f.write(struct.pack('<I', nbits))
        f.write(struct.pack('<I', nbytes))
        f.write(byte_arr)

        # RGB Huffman dictionary
        f.write(b'RGB_HUFFMAN_DICT_START\n')
        f.write(f'{len(rgb_code_map)}\n'.encode())
        for sym, (code_bits, code_str) in rgb_code_map.items():
            f.write(f'{sym} {len(code_bits)} {code_str}\n'.encode())
        f.write(b'RGB_HUFFMAN_DICT_END\n')
        # RGB bitstream
        nbits_rgb, nbytes_rgb, byte_arr_rgb = bits_to_bytes(rgb_bits)
        f.write(struct.pack('<I', nbits_rgb))
        f.write(struct.pack('<I', nbytes_rgb))
        f.write(byte_arr_rgb)

        f.write(b'\nBINARY_DATA_END\n')

def main():
    if len(sys.argv) != 4:
        print("Usage: python ptc_compress_with_rgb.py <input.pts> <output.ptc> <scale_factor>")
        sys.exit(1)
    input_pts = sys.argv[1]
    output_ptc = sys.argv[2]
    s = float(sys.argv[3])

    points_mm, colors = read_pts(input_pts)
    if not points_mm:
        print("Error: No points read", file=sys.stderr)
        sys.exit(1)
    N = len(points_mm)
    points_m = [(x/1000.0, y/1000.0, z/1000.0) for (x,y,z) in points_mm]

    xs = [p[0] for p in points_m]; ys = [p[1] for p in points_m]; zs = [p[2] for p in points_m]
    offset = (min(xs), min(ys), min(zs))

    Qx = [int(round((x - offset[0]) / s)) for x in xs]
    Qy = [int(round((y - offset[1]) / s)) for y in ys]
    Qz = [int(round((z - offset[2]) / s)) for z in zs]

    Dx = [Qx[0]] + [Qx[i] - Qx[i-1] for i in range(1, N)]
    Dy = [Qy[0]] + [Qy[i] - Qy[i-1] for i in range(1, N)]
    Dz = [Qz[0]] + [Qz[i] - Qz[i-1] for i in range(1, N)]
    delta = []
    for i in range(N):
        delta.append(Dx[i]); delta.append(Dy[i]); delta.append(Dz[i])

    # Huffman cho delta
    delta_code_map = huffman_encode(delta)
    delta_bits = encode_to_bits(delta, delta_code_map)

    # Chuan bi RGB: flatten thanh list int (0-255)
    rgb_flat = []
    for c in colors:
        rgb_flat.append(c[0]); rgb_flat.append(c[1]); rgb_flat.append(c[2])
    rgb_code_map = huffman_encode(rgb_flat)
    rgb_bits = encode_to_bits(rgb_flat, rgb_code_map)

    write_ptc(output_ptc, N, s, offset, delta_bits, delta_code_map, rgb_bits, rgb_code_map)
    print(f"Compressed {N} points with RGB Huffman", file=sys.stderr)

if __name__ == '__main__':
    main()
