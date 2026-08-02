`timescale 1ns/1ps

class ram_drv #( parameter
    AW      = 4,
    DW      = 16,
    STRB_W  = 2
);

virtual ram_if #(AW,DW,STRB_W).drv vif;

function new(virtual ram_if #(AW,DW,STRB_W).drv vif);
    this.vif = vif;
endfunction

task automatic drive_idle;
begin
    vif.drv_cb.clear       <= 1'b0;
    vif.drv_cb.arb_wr_addr <= '0;
    vif.drv_cb.arb_wr_data <= '0;
    vif.drv_cb.arb_wr_vld  <= '0;
    vif.drv_cb.arb_rd_addr <= '0;
    vif.drv_cb.arb_rd_vld  <= '0;
    vif.drv_cb.sp_wr_addr  <= '0;
    vif.drv_cb.sp_wr_data  <= '0;
    vif.drv_cb.sp_wr_vld   <= '0;
    vif.drv_cb.sp_rd_addr  <= '0;
    vif.drv_cb.sp_rd_vld   <= 1'b0;
    vif.drv_cb.rmw_wr_addr <= '0;
    vif.drv_cb.rmw_wr_data <= '0;
    vif.drv_cb.rmw_wr_vld  <= '0;
    vif.drv_cb.rmw_rd_addr <= '0;
    vif.drv_cb.rmw_rd_vld  <= 1'b0;
    vif.drv_cb.sp2_wr_addr <= '0;
    vif.drv_cb.sp2_wr_data <= '0;
    vif.drv_cb.sp2_wr_vld  <= '0;
    vif.drv_cb.sp2_rd_addr <= '0;
    vif.drv_cb.sp2_rd_vld  <= 1'b0;
end
endtask

task automatic reset_phase;
begin
    drive_idle();
    vif.drv_cb.rst_n <= 1'b0;
    repeat(5) @(vif.drv_cb);
    vif.drv_cb.rst_n <= 1'b1;
    repeat(2) @(vif.drv_cb);
end
endtask

task automatic smoke_access;
begin
    vif.drv_cb.arb_wr_addr[0] <= 4'h1;
    vif.drv_cb.arb_wr_data[0] <= 16'h1001;
    vif.drv_cb.arb_wr_vld[0]  <= 2'b11;
    vif.drv_cb.arb_rd_addr[1] <= 4'h2;
    vif.drv_cb.arb_rd_vld[1]  <= 1'b1;
    vif.drv_cb.sp_wr_addr     <= 4'h3;
    vif.drv_cb.sp_wr_data     <= 16'h3003;
    vif.drv_cb.sp_wr_vld      <= 2'b11;
    vif.drv_cb.rmw_wr_addr    <= 4'h4;
    vif.drv_cb.rmw_wr_data    <= 16'h40aa;
    vif.drv_cb.rmw_wr_vld     <= 2'b01;
    vif.drv_cb.sp2_wr_addr    <= 4'h5;
    vif.drv_cb.sp2_wr_data    <= 16'h5005;
    vif.drv_cb.sp2_wr_vld     <= 2'b11;
    @(vif.drv_cb);
    vif.drv_cb.arb_wr_vld <= '0;
    vif.drv_cb.arb_rd_vld <= '0;
    vif.drv_cb.sp_wr_vld  <= '0;
    vif.drv_cb.rmw_wr_vld <= '0;
    vif.drv_cb.sp2_wr_vld <= '0;
end
endtask

task automatic run;
begin
    reset_phase();
    smoke_access();
    repeat(20) @(vif.drv_cb);
end
endtask

endclass
