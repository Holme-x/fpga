
% �����Ļ���ڴ�
clear;
clc;
close all;
m_idx = 1;

% ����
org_width   = 640;
org_height  = 480;
hdmi_width  = 1920;
hdmi_height = 1080;

% ��ͼ
org_img = int16(imread('./lena640x480.png'));
% ���ɵ�������ͼ���ڷ���͵���
% k = 0;
% for (h = 1:org_height)
%     for (w = 1:org_width)
%         org_img(h,w,1) = int16(mod(k, 256));
%         org_img(h,w,2) = int16(mod(k, 256));
%         org_img(h,w,3) = int16(mod(k, 256));
%         k = k + 1;
%     end
% end

% ����rawͼ
raw_img = zeros(org_height, org_width*3);
raw_img(:,1:3:org_width*3-2) = org_img(:,:,1);
raw_img(:,2:3:org_width*3-1) = org_img(:,:,2);
raw_img(:,3:3:org_width*3  ) = org_img(:,:,3);
fileID = fopen('./img.raw','w');
fwrite(fileID, raw_img', 'uint8');

% ��5λ������С���Ķ��������ʣ�1~1024
fix_rate    = 73;
rate_coe    = fix((32*32)/fix_rate);

% �������ź��size
resize_width    = bitshift(org_width  * fix_rate, -5);
resize_height   = bitshift(org_height * fix_rate, -5);

% ����ͼ����hdmiͼ���е���ֹ����
roi_bw = hdmi_width/2 - resize_width/2;
roi_bh = hdmi_height/2 - resize_height/2;
roi_ew = hdmi_width/2 + resize_width/2 - 1;
roi_eh = hdmi_height/2 + resize_height/2 - 1;

% ʵʱ����hdmiͼ��
hdmi_img = zeros(hdmi_height, hdmi_width, 3);
for (h = 0:hdmi_height-1)
    for (w = 0:hdmi_width-1)
        roi_vld = (h >= roi_bh) && (h <= roi_eh) && (w >= roi_bw) && (w <= roi_ew);
        if (roi_vld)
            % ����˫���Բ�ֵ4��������꣬�Լ���ֵϵ��
            img_h   = h - roi_bh;
            img_w   = w - roi_bw;
            org_h   = img_h * rate_coe;
            org_w   = img_w * rate_coe;
            int_h   = bitshift(org_h, -5);
            int_w   = bitshift(org_w, -5);
            frac_h  = bitand(org_h, 31);
            frac_w  = bitand(org_w, 31);
            h0      = int_h;
            h1      = h0 + 1;
            w0      = int_w;
            w1      = w0 + 1;
            h1      = min(h1, org_height-1);  % �߽紦��
            w1      = min(w1, org_width-1);
            
            d0      = org_img(h0+m_idx, w0+m_idx, 1);
            d1      = org_img(h0+m_idx, w1+m_idx, 1);
            d2      = org_img(h1+m_idx, w0+m_idx, 1);
            d3      = org_img(h1+m_idx, w1+m_idx, 1);
            d4      = bitshift(d0, 5) + (d1 - d0) * frac_w; % ��������7bitС��
            d5      = bitshift(d2, 5) + (d3 - d2) * frac_w;
            new_img = d4 + bitshift(d5-d4, -5) * frac_h;    % ��������7bitС��
            hdmi_img(h+m_idx,w+m_idx,1) = bitshift(new_img, -5);
            
            d0      = org_img(h0+m_idx, w0+m_idx, 2);
            d1      = org_img(h0+m_idx, w1+m_idx, 2);
            d2      = org_img(h1+m_idx, w0+m_idx, 2);
            d3      = org_img(h1+m_idx, w1+m_idx, 2);
            d4      = bitshift(d0, 5) + (d1 - d0) * frac_w; % ��������7bitС��
            d5      = bitshift(d2, 5) + (d3 - d2) * frac_w;
            new_img = d4 + bitshift(d5-d4, -5) * frac_h;    % ��������7bitС��
            hdmi_img(h+m_idx,w+m_idx,2) = bitshift(new_img, -5);
            
            d0      = org_img(h0+m_idx, w0+m_idx, 3);
            d1      = org_img(h0+m_idx, w1+m_idx, 3);
            d2      = org_img(h1+m_idx, w0+m_idx, 3);
            d3      = org_img(h1+m_idx, w1+m_idx, 3);
            d4      = bitshift(d0, 5) + (d1 - d0) * frac_w; % ��������7bitС��
            d5      = bitshift(d2, 5) + (d3 - d2) * frac_w;
            new_img = d4 + bitshift(d5-d4, -5) * frac_h;    % ��������7bitС��
            hdmi_img(h+m_idx,w+m_idx,3) = bitshift(new_img, -5);
        else
            hdmi_img(h+m_idx,w+m_idx,:) = zeros(1,3);
        end
    end
end

% ��ʾͼ��
imshow(uint8(hdmi_img));

% ͼ��������������/���Աȶ�
sum_d = 0;
sum_img = zeros(hdmi_height, hdmi_width);
for (h = 1:hdmi_height)
    for (w = 1:hdmi_width)
        sum_d = sum_d + hdmi_img(h,w,1);
        sum_img(h,w) = sum_d;
    end
end
