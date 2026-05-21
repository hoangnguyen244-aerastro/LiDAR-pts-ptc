function writePTS(filename, points, colors)
% WRITEPTS Ghi points (mm) va colors ra file .pts (6 cot, khong header)
    fid = fopen(filename, 'w');
    if fid == -1, error('Khong the tao file %s', filename); end
    N = size(points,1);
    for i = 1:N
        fprintf(fid, '%.6f %.6f %.6f %d %d %d\n', ...
            points(i,1), points(i,2), points(i,3), ...
            colors(i,1), colors(i,2), colors(i,3));
    end
    fclose(fid);
end