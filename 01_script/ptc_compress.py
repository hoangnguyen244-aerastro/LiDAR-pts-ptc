#!/usr/bin/env python3
# ptc_compress.py - nen file .pts -> .ptc (quantization + delta + Huffman)
# Usage: python ptc_compress.py <input.pts> <output.ptc> <scale_factor>

import sys
import struct
import heapq
from collections import Counter

def read_pts(filename):
    """Doc file .pts, bo qua dong header neu co, xu ly 6 hoac 7 cot"""
    points = []
    colors = []
    with open(filename, 'r') as f:
        lines = f.readlines()
    if not lines:
        return points, colors
    # Kiem tra dong dau tien co phai header khong
    first_line = lines[0].strip()
    first_parts = first_line.split()
    if len(first_parts) == 1 and first_parts[0].isdigit():
        # Co header: bo qua dong dau
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
            # bo qua cot thu 7 (intensity) neu co
    return points, colors

def write_ptc(filename, N, s, offset, delta, colors, code_map):
    with open(filename, 'wb') as f:
        f.write(b'PTC_FORMAT_V1\nHEADER_START\n')
        f.write(f'num_points: {N}\n'.encode())
        f.write(b'has_color: TRUE\n')
        f.write(f'scale_factor: {s:.10f}\n'.encode())
        f.write(f'offset: {offset[0]:.6f} {offset[1]:.6f} {offset[2]:.6f}\n'.encode())
        f.write(b'point_type: int32\ncolor_space: RGB\n')
        f.write(b'compression_method: HUFFMAN_PYTHON\nchecksum: 00000000\nHEADER_END\n')
        f.write(b'BINARY_DATA_START\n')
        f.write(struct.pack('<I', N))
        f.write(b'HUFFMAN_DICT_START\n')
        f.write(f'{len(code_map)}\n'.encode())
        for sym, (code_bits, _) in code_map.items():
            code_str = ''.join(str(b) for b in code_bits)
            f.write(f'{sym} {len(code_bits)} {code_str}\n'.encode())
        f.write(b'HUFFMAN_DICT_END\n')
        nbits = len(delta)
        nbytes = (nbits + 7) // 8
        f.write(struct.pack('<I', nbits))
        f.write(struct.pack('<I', nbytes))
        byte_arr = bytearray()
        for i in range(0, nbits, 8):
            byte = 0
            for j in range(8):
                if i+j < nbits and delta[i+j]:
                    byte |= (1 << (7-j))
            byte_arr.append(byte)
        f.write(byte_arr)
        for c in colors:
            f.write(struct.pack('BBB', c[0], c[1], c[2]))
        f.write(b'\nBINARY_DATA_END\n')

def build_huffman_tree(symbol_counts):
    heap = [[freq, [sym, ""]] for sym, freq in symbol_counts.items()]
    heapq.heapify(heap)
    while len(heap) > 1:
        lo = heapq.heappop(heap)
        hi = heapq.heappop(heap)
        for pair in lo[1:]:
            pair[1] = '0' + pair[1]
        for pair in hi[1:]:
            pair[1] = '1' + pair[1]
        heapq.heappush(heap, [lo[0] + hi[0]] + lo[1:] + hi[1:])
    code_map = {}
    for sym, code_str in heap[0][1:]:
        code_bits = [int(bit) for bit in code_str]
        code_map[sym] = (code_bits, code_str)
    return code_map

def main():
    if len(sys.argv) != 4:
        print("Usage: python ptc_compress.py <input.pts> <output.ptc> <scale_factor>")
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
        delta.append(Dx[i])
        delta.append(Dy[i])
        delta.append(Dz[i])
    freq = Counter(delta)
    code_map = build_huffman_tree(freq)
    bitstream = []
    for val in delta:
        bits, _ = code_map[val]
        bitstream.extend(bits)
    write_ptc(output_ptc, N, s, offset, bitstream, colors, code_map)
    print(f"Compressed {N} points to {output_ptc}", file=sys.stderr)

if __name__ == '__main__':
    main()
