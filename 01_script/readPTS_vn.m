function [points, colors] = readPTS(filename)
% READPTS Doc file .pts (ASCII), tra ve points (Nx3, mm) va colors (Nx3 uint8)
% Tu dong bo qua dong header neu dong dau tien la mot so nguyen.
% Bo qua cot intensity (thu 7) neu co.

    fid = fopen(filename, 'r');
    if fid == -1
        error('Khong the mo file: %s', filename);
    end

    % Kiem tra dong dau co phai header khong
    first_line = fgetl(fid);
    first_line = strtrim(first_line);
    first_num = str2double(first_line);
    if ~isnan(first_num) && isempty(strfind(first_line, ' ')) && first_num == round(first_num)
        % Co header: bo qua dong nay
        header = true;
        N = first_num;
        frewind(fid);
        fgetl(fid); % bo qua header
    else
        header = false;
        frewind(fid);
        % Dem so dong
        N = 0;
        while ~feof(fid)
            line = fgetl(fid);
            if ischar(line) && ~isempty(strtrim(line))
                N = N + 1;
            end
        end
        frewind(fid);
    end

    points = zeros(N, 3);
    colors = zeros(N, 3, 'uint8');
    idx = 0;
    while ~feof(fid) && idx < N
        line = fgetl(fid);
        if isempty(strtrim(line)), continue; end
        parts = strsplit(strtrim(line));
        if length(parts) >= 6
            idx = idx + 1;
            points(idx,1) = str2double(parts{1});
            points(idx,2) = str2double(parts{2});
            points(idx,3) = str2double(parts{3});
            colors(idx,1) = uint8(str2double(parts{4}));
            colors(idx,2) = uint8(str2double(parts{5}));
            colors(idx,3) = uint8(str2double(parts{6}));
            % bo qua parts{7} neu co
        end
    end
    fclose(fid);
    if idx ~= N
        warning('Chi doc duoc %d/%d diem', idx, N);
        points = points(1:idx,:);
        colors = colors(1:idx,:);
    end
end