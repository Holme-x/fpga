//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�www.openedv.com
//�Ա����̣�http://openedv.taobao.com
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У�����ؾ���
//Copyright(C) ����ԭ�� 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           video_driver
// Last modified Date:  2020/05/04 9:19:08
// Last Version:        V1.0
// Descriptions:        HDMI����
//                      
//----------------------------------------------------------------------------------------
// Created by:          ����ԭ��
// Created date:        2019/05/04 9:19:08
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module video_driver(
    input           pixel_clk,
    input           sys_rst_n,
    
    //RGB�ӿ�
    output          frst    ,
    output          frst_pos,
    output          video_hs,     //��ͬ���ź�
    output          video_vs,     //��ͬ���ź�
    output          video_de,     //����ʹ��
    output  [15:0]  video_rgb,    //RGB888��ɫ����
    
    input   [15:0]  pixel_data,   //���ص�����
    output  [10:0]  pixel_xpos,   //���ص������
    output  [10:0]  pixel_ypos,   //���ص�������
    output  [10:0]  h_disp,       //���ص������
    output  [10:0]  v_disp,       //���ص�������   
    output          data_req
);

//parameter define

//1024*768 �ֱ���ʱ�����,60fps
parameter  H_SYNC   =  12'd44;   //��ͬ��
parameter  H_BACK   =  12'd148;  //����ʾ����
parameter  H_DISP   =  12'd1920; //����Ч����
parameter  H_FRONT  =  12'd88;   //����ʾǰ��
parameter  H_TOTAL  =  12'd2200; //��ɨ������

parameter  V_SYNC   =  12'd5;    //��ͬ��
parameter  V_BACK   =  12'd36;   //����ʾ����
parameter  V_DISP   =  12'd1080; //����Ч����
parameter  V_FRONT  =  12'd4;    //����ʾǰ��
parameter  V_TOTAL  =  12'd1125; //��ɨ������

//reg define
reg  [11:0]  cnt_h;
reg  [11:0]  cnt_v;

//wire define
wire        video_en;
//*****************************************************
//**                    main code
//*****************************************************

assign frst      = (cnt_v == 'd0);
assign frst_pos  = (cnt_v == 'd0) & (cnt_h == H_FRONT);
assign video_de  = video_en;

assign video_hs  = ( cnt_h < H_SYNC ) ? 1'b0 : 1'b1;  //��ͬ���źŸ�ֵ
assign video_vs  = ( cnt_v < V_SYNC ) ? 1'b0 : 1'b1;  //��ͬ���źŸ�ֵ

//ʹ��RGB�������
assign video_en  = (((cnt_h >= H_SYNC+H_BACK) && (cnt_h < H_SYNC+H_BACK+H_DISP))
                 &&((cnt_v >= V_SYNC+V_BACK) && (cnt_v < V_SYNC+V_BACK+V_DISP)))
                 ?  1'b1 : 1'b0;

//RGB888�������
assign video_rgb = video_en ? pixel_data : 24'd0;

//�������ص���ɫ��������
assign data_req = (((cnt_h >= H_SYNC+H_BACK-1'b1) && 
                    (cnt_h < H_SYNC+H_BACK+H_DISP-1'b1))
                  && ((cnt_v >= V_SYNC+V_BACK) && (cnt_v < V_SYNC+V_BACK+V_DISP)))
                  ?  1'b1 : 1'b0;

//���ص�����
assign pixel_xpos = data_req ? (cnt_h - (H_SYNC + H_BACK - 1'b1)) : 11'd0;
assign pixel_ypos = data_req ? (cnt_v - (V_SYNC + V_BACK - 1'b1)) : 11'd0;

//�г��ֱ���
assign h_disp = H_DISP;
assign v_disp = V_DISP; 

//�м�����������ʱ�Ӽ���
always @(posedge pixel_clk ) begin
    if (!sys_rst_n)
        cnt_h <= 12'd0;
    else begin
        if(cnt_h < H_TOTAL - 1'b1)
            cnt_h <= cnt_h + 1'b1;
        else 
            cnt_h <= 12'd0;
    end
end

//�����������м���
always @(posedge pixel_clk ) begin
    if (!sys_rst_n)
        cnt_v <= 12'd0;
    else if(cnt_h == H_TOTAL - 1'b1) begin
        if(cnt_v < V_TOTAL - 1'b1)
            cnt_v <= cnt_v + 1'b1;
        else 
            cnt_v <= 12'd0;
    end
end

endmodule