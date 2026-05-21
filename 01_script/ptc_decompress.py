#!/usr/bin/env python3
# ptc_decompress.py - giai nen .ptc -> .pts

import sys
import struct

def read_ptc(filename):
    with open(filename, 'rb') as f:
        line = f.readline().decode().strip()
        if line != 'PTC_FORMAT_V1':
            raise ValueError('Invalid PTC format')
        line = f.readline().decode().strip()
        if line != 'HEADER_START':
            raise ValueError('Missing HEADER_START')
        header = {}
        while True:
            line = f.readline().decode().strip()
            if line == 'HEADER_END':
                break
            if not line:
                continue
            key, val = line.split(':', 1)
            header[key.strip()] = val.strip()
        N = int(header['num_points'])
        s = float(header['scale_factor'])
        off = [float(x) for x in header['offset'].split()]
        offset = tuple(off)
        while True:
            line = f.readline().decode().strip()
            if line == 'BINARY_DATA_START':
                break
        N_read = struct.unpack('<I', f.read(4))[0]
        if N_read != N:
            print(f"Warning: N mismatch {N_read} vs {N}", file=sys.stderr)
            N = N_read
        line = f.readline().decode().strip()
        if line != 'HUFFMAN_DICT_START':
            raise ValueError('Missing HUFFMAN_DICT_START')
        nSym = int(f.readline().decode().strip())
        code_map = {}
        for _ in range(nSym):
            parts = f.readline().decode().split()
            sym = int(parts[0])
            _len = int(parts[1])
            code_str = parts[2]
            code_map[code_str] = sym
        line = f.readline().decode().strip()
        if line != 'HUFFMAN_DICT_END':
            raise ValueError('Missing HUFFMAN_DICT_END')
        nbits = struct.unpack('<I', f.read(4))[0]
        nbytes = struct.unpack('<I', f.read(4))[0]
        byte_data = f.read(nbytes)
        bits = []
        for byte in byte_data:
            for j in range(7, -1, -1):
                bits.append((byte >> j) & 1)
        bits = bits[:nbits]
        delta = []
        pos = 0
        max_len = max(len(cs) for cs in code_map.keys())
        while pos < nbits:
            found = False
            for l in range(1, min(max_len, nbits-pos)+1):
                code_str = ''.join(str(b) for b in bits[pos:pos+l])
                if code_str in code_map:
                    delta.append(code_map[code_str])
                    pos += l
                    found = True
                    break
            if not found:
                raise ValueError(f"Decoding failed at bit {pos}")
        if len(delta) < 3*N:
            delta.extend([0]*(3*N - len(delta)))
        else:
            delta = delta[:3*N]
        colors = []
        for _ in range(N):
            r = f.read(1)[0]
            g = f.read(1)[0]
            b = f.read(1)[0]
            colors.append((r,g,b))
        return N, s, offset, delta, colors

def write_pts(filename, points_mm, colors):
    with open(filename, 'w') as f:
        for i in range(len(points_mm)):
            p = points_mm[i]
            c = colors[i]
            f.write(f"{p[0]:.6f} {p[1]:.6f} {p[2]:.6f} {c[0]} {c[1]} {c[2]}\n")

def main():
    if len(sys.argv) != 3:
        print("Usage: python ptc_decompress.py <input.ptc> <output.pts>")
        sys.exit(1)
    input_ptc = sys.argv[1]
    output_pts = sys.argv[2]
    N, s, offset, delta, colors = read_ptc(input_ptc)
    Dx = delta[0::3]; Dy = delta[1::3]; Dz = delta[2::3]
    Qx = [0]*N; Qy = [0]*N; Qz = [0]*N
    Qx[0] = Dx[0]; Qy[0] = Dy[0]; Qz[0] = Dz[0]
    for i in range(1, N):
        Qx[i] = Qx[i-1] + Dx[i]
        Qy[i] = Qy[i-1] + Dy[i]
        Qz[i] = Qz[i-1] + Dz[i]
    points_m = [(Qx[i]*s + offset[0], Qy[i]*s + offset[1], Qz[i]*s + offset[2]) for i in range(N)]
    points_mm = [(x*1000.0, y*1000.0, z*1000.0) for (x,y,z) in points_m]
    write_pts(output_pts, points_mm, colors)
    print(f"Decompressed {N} points to {output_pts}", file=sys.stderr)

if __name__ == '__main__':
    main()
