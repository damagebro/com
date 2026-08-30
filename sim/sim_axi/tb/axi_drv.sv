`timescale 1ns/1ps

class axi_drv #( parameter
    CASE_KIND = 0,
    WCH       = 1,
    RCH       = 1,
    AW        = 16,
    DW        = 32,
    EBUS_LW   = 16,
    LW        = 4,
    IW        = 1,
    UW        = 2
);

virtual axi_if #(WCH,RCH,AW,DW,EBUS_LW,LW,IW,UW) vif;

function new(virtual axi_if #(WCH,RCH,AW,DW,EBUS_LW,LW,IW,UW) vif);
    this.vif = vif;
endfunction

task automatic drive_idle;
begin
    vif.drv_cb.clear                   <= 1'b0;
    vif.drv_cb.cfg_mem_ctrl            <= '0;
    vif.drv_cb.cfg_max_blen_m1         <= 8'd3;
    vif.drv_cb.cfg_rch_max_rdcmd_osd  <= '0;
    vif.drv_cb.wa_user                 <= '0;
    vif.drv_cb.wa_addr                 <= '0;
    vif.drv_cb.wa_bytelen              <= '0;
    vif.drv_cb.wa_valid                <= '0;
    vif.drv_cb.wd_data                 <= '0;
    vif.drv_cb.wd_valid                <= '0;
    vif.drv_cb.ra_user                 <= '0;
    vif.drv_cb.ra_addr                 <= '0;
    vif.drv_cb.ra_bytelen              <= '0;
    vif.drv_cb.ra_valid                <= '0;
    vif.drv_cb.rd_ready                <= '1;
    vif.drv_cb.axi_awready             <= 1'b1;
    vif.drv_cb.axi_wready              <= 1'b1;
    vif.drv_cb.axi_bresp               <= 2'b00;
    vif.drv_cb.axi_bid                 <= '0;
    vif.drv_cb.axi_bvalid              <= 1'b0;
    vif.drv_cb.axi_arready             <= 1'b1;
    vif.drv_cb.axi_rresp               <= 2'b00;
    vif.drv_cb.axi_rid                 <= '0;
    vif.drv_cb.axi_rdata               <= '0;
    vif.drv_cb.axi_rlast               <= 1'b0;
    vif.drv_cb.axi_rvalid              <= 1'b0;
end
endtask

task automatic reset_phase;
begin
    drive_idle();
    vif.drv_cb.rst_n <= 1'b0;
    repeat(5) @(vif.drv_cb);
    vif.drv_cb.rst_n <= 1'b1;
    @(vif.drv_cb);
end
endtask

task automatic send_write(
    input logic [UW-1:0]       user,
    input logic [AW-1:0]       addr,
    input logic [EBUS_LW-1:0]  bytelen,
    input integer              beat_num,
    input logic [DW-1:0]       data_base
);
integer last_w_hs_cycle;
integer cycle_cnt;
begin
    vif.drv_cb.wa_user[0]    <= user;
    vif.drv_cb.wa_addr[0]    <= addr;
    vif.drv_cb.wa_bytelen[0] <= bytelen;
    vif.drv_cb.wa_valid[0]   <= 1'b1;
    do @(vif.drv_cb); while( !vif.drv_cb.wa_ready[0] );
    vif.drv_cb.wa_valid[0] <= 1'b0;

    last_w_hs_cycle = -1;
    cycle_cnt = 0;
    for( integer i=0; i<beat_num; i=i+1 ) begin
        vif.drv_cb.wd_data[0]  <= data_base+DW'(i);
        vif.drv_cb.wd_valid[0] <= 1'b1;
        do begin
            @(vif.drv_cb);
            cycle_cnt = cycle_cnt+1;
        end while( !vif.drv_cb.wd_ready[0] );
        if( last_w_hs_cycle>=0 && cycle_cnt!=last_w_hs_cycle+1 )
            $fatal(1, "AXI write data inserted a bubble at beat %0d", i);
        last_w_hs_cycle = cycle_cnt;
    end
    vif.drv_cb.wd_valid[0] <= 1'b0;

    repeat(4) @(vif.drv_cb);
    vif.drv_cb.axi_bvalid <= 1'b1;
    do @(vif.drv_cb); while( !vif.drv_cb.axi_bready );
    vif.drv_cb.axi_bvalid <= 1'b0;
end
endtask

task automatic send_read(
    input logic [UW-1:0]       user,
    input logic [AW-1:0]       addr,
    input logic [EBUS_LW-1:0]  bytelen,
    input integer              beat_num,
    input logic [DW-1:0]       data_base
);
integer last_r_hs_cycle;
integer cycle_cnt;
begin
    vif.drv_cb.ra_user[0]    <= user;
    vif.drv_cb.ra_addr[0]    <= addr;
    vif.drv_cb.ra_bytelen[0] <= bytelen;
    vif.drv_cb.ra_valid[0]   <= 1'b1;
    do @(vif.drv_cb); while( !vif.drv_cb.ra_ready[0] );
    vif.drv_cb.ra_valid[0] <= 1'b0;
    do @(vif.drv_cb); while( !vif.drv_cb.axi_arvalid );

    fork
        begin
            last_r_hs_cycle = -1;
            cycle_cnt = 0;
            for( integer i=0; i<beat_num; i=i+1 ) begin
                vif.drv_cb.axi_rdata  <= data_base+DW'(i);
                vif.drv_cb.axi_rlast  <= (i==beat_num-1);
                vif.drv_cb.axi_rvalid <= 1'b1;
                do begin
                    @(vif.drv_cb);
                    cycle_cnt = cycle_cnt+1;
                end while( !vif.drv_cb.axi_rready );
                if( last_r_hs_cycle>=0 && cycle_cnt!=last_r_hs_cycle+1 )
                    $fatal(1, "AXI read data inserted a bubble at beat %0d", i);
                last_r_hs_cycle = cycle_cnt;
            end
            vif.drv_cb.axi_rvalid <= 1'b0;
            vif.drv_cb.axi_rlast  <= 1'b0;
        end
        begin
            do @(vif.drv_cb); while( !vif.drv_cb.rd_valid[0] );
            for( integer i=1; i<beat_num; i=i+1 ) begin
                @(vif.drv_cb);
                if( !vif.drv_cb.rd_valid[0] )
                    $fatal(1, "EBUS read data inserted a bubble at beat %0d", i);
            end
        end
    join
end
endtask

task automatic run;
begin
    reset_phase();
    if( CASE_KIND==0 ) begin
        send_write(UW'(1), AW'(0), EBUS_LW'(64), 16, DW'('h1000));
        repeat(20) @(vif.drv_cb);
    end
    else if( CASE_KIND==1 ) begin
        send_read(UW'(2), AW'(0), EBUS_LW'(64), 16, DW'('h55aa_0000));
        repeat(20) @(vif.drv_cb);
    end
    else begin
        send_write('0, AW'('h40), EBUS_LW'(64), 16, DW'('hd00d_0000));
        send_read('0, AW'('h80), EBUS_LW'(64), 16, DW'('hcafe_0000));
        repeat(30) @(vif.drv_cb);
    end
end
endtask

endclass
