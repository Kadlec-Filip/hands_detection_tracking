clear all;
close all;
% vid1 = tracking while writing, erasing (nonstatic camera, fast movement,
%        bad lighting, partial overlapping included, but not as drastic
%        as in vid2,vid3,vid4)
% vid2 = fast movement + moving camera test
% vid3 = partial overlays + big overlay  test (mix up of tracked 
%        hands due to one huge overlay)
% vid4 = partial overlays + bad lighting test
vid=VideoReader('vid1.mp4');
numFrames = vid.NumFrames;

% cs = centroids
cs = [0 0;0 0];
for i = 1:1:numFrames
    frame = read(vid,i);
    
    % second condition here only due to overlay testing. the hands are
    % detected again once centroids are at the same coordinates
    % (due to viddeo 3)
    if i == 1 || (sqrt((cs(1,1)-cs(2,1))^2+(cs(1,2)-cs(2,2))^2) <= 5)
        [hue,s,v]=rgb2hsv(frame);
        [w,h]=size(frame(:,:,1));
        
        segment =zeros(w,h);
        % R,G,B,saturarion,hue segmentation
        segment(1:size(frame,1),1:size(frame,2)) =...
            ((frame(:,:,1)>95) & (frame(:,:,2)>40) & ...
            (frame(:,:,3)>20) & 0.01<=hue & hue<=0.1 & ...
            (s>=0.22) & (s<=0.68));
            
        frame_bin=imbinarize(segment);
        % TODO if area of blob > threshold - add to cs, otherwise discard
        BW = bwareafilt(frame_bin, 2, 'Largest');
        props = regionprops(BW,'Centroid','BoundingBox');
        cs = [];
        cs = [cs ; props(1).Centroid];
        cs = [cs ; props(2).Centroid];
        
        imshow(frame);
        hold on
        plot(cs(:,1), cs(:,2), 'r*');
        hold off
        
        % finding dynamically at the beginning of video size of 
        % search windows
        bb = []; %             width                  height
        bb = [bb ; props(1).BoundingBox(3) props(1).BoundingBox(4)];
        bb = [bb ; props(2).BoundingBox(3) props(2).BoundingBox(4)];
        search_area_x = round(max(bb(:,1))*0.7);
        search_area_y = round(max(bb(:,2))*0.7);
    else
        segment = zeros(search_area_y,search_area_x,size(cs,1));
        init_centroids_coord = zeros(size(cs,1),size(cs,2));
        for k = 1:size(cs,1)
            % search in the size of window OR smaller, if window is close
            % to the edge of the frame
            rows = round(max(1,(cs(k,2)-search_area_y/2))):round(min(w,(cs(k,2)+search_area_y/2)));
            cols = round(max(1,(cs(k,1)-search_area_x/2))):round(min(h,(cs(k,1)+search_area_x/2)));
            
            % top left coordinate of search window of k-th centroid
            init_centroids_coord(k,:) = [cols(1),rows(1)];
            
            %segmenting hands from frame only at given search windows
            search_window = frame(rows,cols,:);
            
            [hue,s,v]=rgb2hsv(search_window);
            
            segment(1:size(search_window,1),1:size(search_window,2),k) ...
                = ((search_window(:,:,1)>95) & (search_window(:,:,2)>40) & ...
                (search_window(:,:,3)>20) & 0.01<=hue & hue<=0.1 & ...
                (s>=0.22) & (s<=0.68));

        end
        % for each search window (hand) find centroid
        for k = 1:size(cs,1)
            temp_bin_window = imbinarize(segment(:,:,k));
            BW = bwareafilt(temp_bin_window, 1, 'Largest');
            props = regionprops(BW,'Centroid');
            cs(k,:) = props.Centroid;
        end
        % recompute local coordinates (in search window) back to frame
        % coordinates
        cs(:,1)= cs(:,1) + init_centroids_coord(:,1);
        cs(:,2)= cs(:,2) + init_centroids_coord(:,2);
        
        % plot current frame with found centroids of hands
        imshow(frame);
        hold on
        plot(cs(:,1), cs(:,2), 'r*');
        hold off
    end
    % without pause the matlab cannot keep up and is not plotting frames
    pause(0.05)
end
