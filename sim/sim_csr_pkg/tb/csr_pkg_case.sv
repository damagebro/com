`timescale 1ns/1ps

module csr_pkg_case #(
    parameter EBUS_DW = 64
)
(
    output logic o_done
);

localparam CSR_AW     = 16;
localparam EBUS_AW    = 64;
localparam EBUS_LW    = 32;
localparam EBUS_UW    = 1;
localparam EBUS_BYTES = EBUS_DW/8;
localparam EBUS_WORDS = EBUS_DW/32;
localparam READ_BURST_NUM = EBUS_DW>=256 ? 12 : 8;
localparam RESULT_DEPTH = 16;
localparam RESULT_RAM_AW = $clog2(RESULT_DEPTH/2);

logic                    clk;
logic                    rst_n;
logic                    clear;

logic [EBUS_AW-1:0]      wr_cfg_pkg_addr;
logic [EBUS_LW-1:0]      wr_cfg_pkg_bytelen;
logic                    wr_cfg_start;
logic                    wr_cfg_abort;
logic                    wr_busy;
logic                    wr_done;
logic                    wr_error;
logic [7:0]              wr_error_code;
logic [31:0]             wr_reg_done_cnt;
logic [15:0]             wr_jump_cnt;
logic [EBUS_AW-1:0]      wr_ra_addr;
logic [EBUS_LW-1:0]      wr_ra_bytelen;
logic                    wr_ra_valid;
logic                    wr_ra_ready;
logic [EBUS_DW-1:0]      wr_rd_data;
logic                    wr_rd_last;
logic                    wr_rd_valid;
logic                    wr_rd_ready;
logic                    wr_csr_req_write;
logic [CSR_AW-1:0]       wr_csr_req_addr;
logic [31:0]             wr_csr_req_wdata;
logic [3:0]              wr_csr_req_wstrb;
logic                    wr_csr_req_valid;
logic                    wr_csr_req_ready;

logic [EBUS_AW-1:0]      rd_cfg_pkg_addr;
logic [EBUS_LW-1:0]      rd_cfg_pkg_bytelen;
logic                    rd_cfg_start;
logic                    rd_cfg_abort;
logic                    rd_busy;
logic                    rd_done;
logic                    rd_error;
logic [7:0]              rd_error_code;
logic [31:0]             rd_reg_done_cnt;
logic [15:0]             rd_jump_cnt;
logic [EBUS_AW-1:0]      rd_ra_addr;
logic [EBUS_LW-1:0]      rd_ra_bytelen;
logic                    rd_ra_valid;
logic                    rd_ra_ready;
logic [EBUS_DW-1:0]      rd_rd_data;
logic                    rd_rd_last;
logic                    rd_rd_valid;
logic                    rd_rd_ready;
logic [EBUS_AW-1:0]      rd_wa_addr;
logic [EBUS_LW-1:0]      rd_wa_bytelen;
logic                    rd_wa_valid;
logic                    rd_wa_ready;
logic [EBUS_DW-1:0]      rd_wd_data;
logic                    rd_wd_valid;
logic                    rd_wd_ready;
logic                    rd_wb_valid;
logic                    rd_csr_req_write;
logic [CSR_AW-1:0]       rd_csr_req_addr;
logic [31:0]             rd_csr_req_wdata;
logic [3:0]              rd_csr_req_wstrb;
logic                    rd_csr_req_valid;
logic                    rd_csr_req_ready;
logic [31:0]             rd_csr_rsp_rdata;
logic                    rd_csr_rsp_rvalid;
wire                     rd_result_ram_ce_n;
wire                     rd_result_ram_we_n;
wire [RESULT_RAM_AW-1:0] rd_result_ram_addr;
wire [127:0]             rd_result_ram_wr_data;
wire [127:0]             rd_result_ram_rd_data;

logic [31:0]             pkg_mem [0:1023];
logic [31:0]             result_mem [0:1023];
integer                  wr_req_cnt;
logic                    ctrl_mode = 1'b0;
logic                    allow_next_ra = 1'b1;
logic                    bad_next_last = 1'b0;
integer                  wr_ra_cnt = 0;
integer                  rd_ra_cnt = 0;
integer                  wr_ctrl_cnt = 0;
integer                  rd_ctrl_cnt = 0;
integer                  wr_next_cycle = 0;
integer                  rd_next_cycle = 0;
integer                  wr_first_cycle = 0;
integer                  rd_wb_cycle = 0;
integer                  cycle_cnt = 0;

always @(posedge clk)
    cycle_cnt <= cycle_cnt + 1;
integer                  result_ram_wr_cnt;
integer                  result_ram_rd_cnt;

clocking cb @(posedge clk);
    default input #1step output #0;
    output rst_n;
    output clear;
    output wr_cfg_pkg_addr;
    output wr_cfg_pkg_bytelen;
    output wr_cfg_start;
    output wr_cfg_abort;
    output wr_ra_ready;
    output wr_rd_data;
    output wr_rd_last;
    output wr_rd_valid;
    output wr_csr_req_ready;
    output rd_cfg_pkg_addr;
    output rd_cfg_pkg_bytelen;
    output rd_cfg_start;
    output rd_cfg_abort;
    output rd_ra_ready;
    output rd_rd_data;
    output rd_rd_last;
    output rd_rd_valid;
    output rd_wa_ready;
    output rd_wd_ready;
    output rd_wb_valid;
    output rd_csr_req_ready;
    output rd_csr_rsp_rdata;
    output rd_csr_rsp_rvalid;
    input  wr_busy;
    input  wr_done;
    input  wr_error;
    input  wr_error_code;
    input  wr_reg_done_cnt;
    input  wr_jump_cnt;
    input  wr_ra_addr;
    input  wr_ra_bytelen;
    input  wr_ra_valid;
    input  wr_rd_ready;
    input  wr_csr_req_write;
    input  wr_csr_req_addr;
    input  wr_csr_req_wdata;
    input  wr_csr_req_wstrb;
    input  wr_csr_req_valid;
    input  rd_busy;
    input  rd_done;
    input  rd_error;
    input  rd_error_code;
    input  rd_reg_done_cnt;
    input  rd_jump_cnt;
    input  rd_ra_addr;
    input  rd_ra_bytelen;
    input  rd_ra_valid;
    input  rd_rd_ready;
    input  rd_wa_addr;
    input  rd_wa_bytelen;
    input  rd_wa_valid;
    input  rd_wd_data;
    input  rd_wd_valid;
    input  rd_csr_req_write;
    input  rd_csr_req_addr;
    input  rd_csr_req_valid;
endclocking

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

function automatic [EBUS_DW-1:0] F_pkg_beat;
input [EBUS_AW-1:0] beat_addr;
begin
    F_pkg_beat = '0;
    for( int i=0; i<EBUS_WORDS; i=i+1 )
        F_pkg_beat[i*32 +: 32] = pkg_mem[10'((beat_addr>>2)+i)];
end
endfunction

function automatic [31:0] F_csr_rdata;
input [31:0] csr_addr;
begin
    F_csr_rdata = 32'h9000_0000 | csr_addr;
end
endfunction

task automatic T_check_wr_req;
input integer idx;
input [CSR_AW-1:0] addr;
input [31:0] data;
begin
    if( !cb.wr_csr_req_write || cb.wr_csr_req_addr!==addr || cb.wr_csr_req_wdata!==data ||
        cb.wr_csr_req_wstrb!==4'hf )
        $fatal(1, "CSR package write mismatch idx=%0d addr=%h data=%h", idx,
               cb.wr_csr_req_addr,cb.wr_csr_req_wdata);
end
endtask

task automatic T_check_result;
input integer word_idx;
input [31:0] exp_data;
begin
    if( result_mem[word_idx]!==exp_data )
        $fatal(1, "CSR package result mismatch word=%0d exp=%h act=%h",
               word_idx,exp_data,result_mem[word_idx]);
end
endtask

task automatic T_put_jump;
ref integer ptr;
input [31:0] addr;
input [31:0] bytelen;
input integer header_words;
begin
    pkg_mem[ptr] = 32'h4000_0000 | (32'(header_words)<<24);
    pkg_mem[ptr+1] = addr;
    pkg_mem[ptr+2] = '0;
    pkg_mem[ptr+3] = bytelen;
    for( int i=4; i<header_words; i=i+1 )
        pkg_mem[ptr+i] = '0;
    ptr = ptr + header_words;
end
endtask

task automatic T_put_access;
ref integer ptr;
input logic is_read;
begin
    if( is_read ) begin
        pkg_mem[ptr] = 32'h2300_0001;
        pkg_mem[ptr+1] = 32'h0000_0f04;
        pkg_mem[ptr+2] = '0;
        pkg_mem[ptr+3] = 32'h0000_0200;
        ptr = ptr + 4;
    end
    else begin
        pkg_mem[ptr] = 32'h0100_0001;
        pkg_mem[ptr+1] = 32'h0000_0200;
        pkg_mem[ptr+2] = 32'h1234_5678;
        ptr = ptr + 3;
    end
end
endtask

//Public-interface checks: overlap, ordering, duplicate detection, drain and restart.
task automatic T_jump_case;
input logic is_read;
input integer scenario;
integer ptr;
integer expected_error;
integer expected_ra;
integer expected_jump;
integer expected_access;
integer seen_done;
integer actual_access;
begin
    @(cb);
    ptr = 'hc04>>2;
    expected_error = 0;
    expected_ra = 2;
    expected_jump = 1;
    expected_access = 1;
    seen_done = 0;
    allow_next_ra = scenario!=7;
    bad_next_last = scenario==11;
    pkg_mem['he04>>2] = 32'hf100_0000;
    case( scenario )
        1: begin
            T_put_access(ptr,is_read);
            T_put_jump(ptr,32'('he04),32'd4,4);
            T_put_access(ptr,is_read);
            expected_access = 2;
        end
        2: begin
            T_put_jump(ptr,32'('he04),32'd4,4);
            T_put_jump(ptr,32'('he04),32'd4,4);
            expected_error = 9;
            expected_ra = 1;
            expected_jump = 0;
            expected_access = 0;
        end
        5: begin
            T_put_access(ptr,is_read);
            expected_error = 4;
            expected_ra = 1;
            expected_jump = 0;
        end
        6: begin
            T_put_jump(ptr,32'('he06),32'd4,4);
            expected_error = 5;
            expected_ra = 1;
            expected_jump = 0;
            expected_access = 0;
        end
        8: begin
            T_put_jump(ptr,32'('hc04),32'd16,4);
            expected_error = 8;
            expected_access = 0;
        end
        9: begin
            T_put_access(ptr,is_read);
            T_put_jump(ptr,32'('he04),32'd4,4);
        end
        default: begin
            T_put_jump(ptr,32'('he04),32'd4,scenario==10 ? 8 : 4);
            T_put_access(ptr,is_read);
            if( scenario==3 || scenario==4 ) begin
                pkg_mem[ptr] = scenario==3 ? 32'hf100_0000 : 32'h5100_0000;
                ptr = ptr + 1;
                expected_error = scenario==3 ? 4 : 1;
                expected_jump = 0;
            end
            if( scenario==7 ) begin
                expected_error = 7;
                expected_jump = 0;
            end
            if( scenario==11 )
                expected_error = 4;
        end
    endcase
    if( is_read ) begin
        cb.rd_cfg_pkg_addr <= 64'hc04;
        cb.rd_cfg_pkg_bytelen <= 32'((ptr-('hc04>>2))*4);
        cb.rd_cfg_start <= 1'b1;
    end
    else begin
        cb.wr_cfg_pkg_addr <= 64'hc04;
        cb.wr_cfg_pkg_bytelen <= 32'((ptr-('hc04>>2))*4);
        cb.wr_cfg_start <= 1'b1;
    end
    @(cb);
    cb.wr_cfg_start <= 1'b0;
    cb.rd_cfg_start <= 1'b0;
    if( scenario==7 ) begin
        do @(cb); while( is_read ? !(cb.rd_ra_addr==64'('he04) && cb.rd_ra_valid) :
                                  !(cb.wr_ra_addr==64'('he04) && cb.wr_ra_valid) );
        if( is_read )
            cb.rd_cfg_abort <= 1'b1;
        else
            cb.wr_cfg_abort <= 1'b1;
        @(cb);
        cb.wr_cfg_abort <= 1'b0;
        cb.rd_cfg_abort <= 1'b0;
        expected_access = is_read ? rd_ctrl_cnt : wr_ctrl_cnt;
        repeat(4) @(cb);
        allow_next_ra = 1'b1;
    end
    do begin
        @(cb);
        if( is_read ? cb.rd_done : cb.wr_done )
            seen_done = seen_done + 1;
    end while( is_read ? cb.rd_busy : cb.wr_busy );
    repeat(2) @(cb);
    actual_access = is_read ? rd_ctrl_cnt : wr_ctrl_cnt;
    if( (is_read ? cb.rd_error_code : cb.wr_error_code)!==8'(expected_error) ||
        (is_read ? cb.rd_jump_cnt : cb.wr_jump_cnt)!==16'(expected_jump) ||
        (is_read ? rd_ra_cnt : wr_ra_cnt)!=expected_ra || actual_access!=expected_access ||
        seen_done!=(expected_error==0 ? 1 : 0) )
        $fatal(1, "jump case read=%0b test=%0d code=%0d jump=%0d ra=%0d access=%0d done=%0d",
               is_read,scenario,is_read ? cb.rd_error_code : cb.wr_error_code,
               is_read ? cb.rd_jump_cnt : cb.wr_jump_cnt,is_read ? rd_ra_cnt : wr_ra_cnt,
               actual_access,seen_done);
    if( scenario==0 || scenario==3 || scenario==4 || scenario==10 ) begin
        if( is_read ? rd_next_cycle>=rd_wb_cycle : wr_next_cycle>=wr_first_cycle )
            $fatal(1, "prefetch did not overlap current execution read=%0b test=%0d",is_read,scenario);
        $display("JUMP overlap read=%0b test=%0d lead=%0d cycles",is_read,scenario,
                 is_read ? rd_wb_cycle-rd_next_cycle : wr_first_cycle-wr_next_cycle);
    end
    if( is_read && expected_access>0 && expected_error==0 ) begin
        T_check_result('hf04>>2,32'h200);
        T_check_result('hf08>>2,F_csr_rdata(32'h200));
    end
    $display("JUMP case PASS DW=%0d read=%0b test=%0d",EBUS_DW,is_read,scenario);
    bad_next_last = 1'b0;
end
endtask

//Writer package EBUS read responder.
initial begin: wr_pkg_driver
    logic active;
    logic [EBUS_AW-1:0] beat_addr;
    integer beat_rem;
    integer latency;
    active = 1'b0;
    latency = 0;
    beat_addr = '0;
    beat_rem = 0;
    wr_ra_ready = 1'b0;
    wr_rd_data = '0;
    wr_rd_last = 1'b0;
    wr_rd_valid = 1'b0;
    forever begin
        @(cb);
        if( !rst_n ) begin
            active = 1'b0;
            cb.wr_ra_ready <= 1'b0;
            cb.wr_rd_valid <= 1'b0;
            cb.wr_rd_last <= 1'b0;
        end
        else begin
            cb.wr_ra_ready <= allow_next_ra || wr_ra_cnt==0;
            if( wr_cfg_start )
                wr_ra_cnt = 0;
            if( latency>0 ) begin
                latency = latency - 1;
                if( latency==0 )
                    cb.wr_rd_valid <= 1'b1;
            end
            if( cb.wr_ra_valid && wr_ra_ready ) begin
                if( active )
                    $fatal(1, "writer EBUS accepts overlapping package read");
                active = 1'b1;
                wr_ra_cnt = wr_ra_cnt + 1;
                if( wr_ra_cnt==2 )
                    wr_next_cycle = cycle_cnt;
                beat_addr = cb.wr_ra_addr & ~(EBUS_AW'(EBUS_BYTES-1));
                beat_rem = (cb.wr_ra_addr[$clog2(EBUS_BYTES)-1:0] + cb.wr_ra_bytelen + EBUS_BYTES-1)/EBUS_BYTES;
                cb.wr_rd_data <= F_pkg_beat(beat_addr);
                cb.wr_rd_last <= beat_rem==1 && !(bad_next_last && wr_ra_cnt==2);
                latency = ctrl_mode ? 8 : 0;
                cb.wr_rd_valid <= !ctrl_mode;
            end
            else if( wr_rd_valid && cb.wr_rd_ready ) begin
                if( beat_rem==1 ) begin
                    active = 1'b0;
                    beat_rem = 0;
                    cb.wr_rd_valid <= 1'b0;
                    cb.wr_rd_last <= 1'b0;
                end
                else begin
                    beat_addr = beat_addr + EBUS_BYTES;
                    beat_rem = beat_rem - 1;
                    cb.wr_rd_data <= F_pkg_beat(beat_addr);
                    cb.wr_rd_last <= beat_rem==1;
                end
            end
        end
    end
end

//Reader package EBUS read responder.
initial begin: rd_pkg_driver
    logic active;
    logic [EBUS_AW-1:0] beat_addr;
    integer beat_rem;
    integer latency;
    active = 1'b0;
    latency = 0;
    beat_addr = '0;
    beat_rem = 0;
    rd_ra_ready = 1'b0;
    rd_rd_data = '0;
    rd_rd_last = 1'b0;
    rd_rd_valid = 1'b0;
    forever begin
        @(cb);
        if( !rst_n ) begin
            active = 1'b0;
            cb.rd_ra_ready <= 1'b0;
            cb.rd_rd_valid <= 1'b0;
            cb.rd_rd_last <= 1'b0;
        end
        else begin
            cb.rd_ra_ready <= allow_next_ra || rd_ra_cnt==0;
            if( rd_cfg_start )
                rd_ra_cnt = 0;
            if( latency>0 ) begin
                latency = latency - 1;
                if( latency==0 )
                    cb.rd_rd_valid <= 1'b1;
            end
            if( cb.rd_ra_valid && rd_ra_ready ) begin
                if( active )
                    $fatal(1, "reader EBUS accepts overlapping package read");
                active = 1'b1;
                rd_ra_cnt = rd_ra_cnt + 1;
                if( rd_ra_cnt==2 )
                    rd_next_cycle = cycle_cnt;
                beat_addr = cb.rd_ra_addr & ~(EBUS_AW'(EBUS_BYTES-1));
                beat_rem = (cb.rd_ra_addr[$clog2(EBUS_BYTES)-1:0] + cb.rd_ra_bytelen + EBUS_BYTES-1)/EBUS_BYTES;
                cb.rd_rd_data <= F_pkg_beat(beat_addr);
                cb.rd_rd_last <= beat_rem==1 && !(bad_next_last && rd_ra_cnt==2);
                latency = ctrl_mode ? 8 : 0;
                cb.rd_rd_valid <= !ctrl_mode;
            end
            else if( rd_rd_valid && cb.rd_rd_ready ) begin
                if( beat_rem==1 ) begin
                    active = 1'b0;
                    beat_rem = 0;
                    cb.rd_rd_valid <= 1'b0;
                    cb.rd_rd_last <= 1'b0;
                end
                else begin
                    beat_addr = beat_addr + EBUS_BYTES;
                    beat_rem = beat_rem - 1;
                    cb.rd_rd_data <= F_pkg_beat(beat_addr);
                    cb.rd_rd_last <= beat_rem==1;
                end
            end
        end
    end
end

//CSR write target and scoreboard.
initial begin
    logic prev_wr_hs;
    integer stall_rem;
    stall_rem = 0;
    wr_csr_req_ready = 1'b0;
    wr_req_cnt = 0;
    prev_wr_hs = 1'b0;
    forever begin
        @(cb);
        if( !rst_n ) begin
            cb.wr_csr_req_ready <= 1'b0;
            wr_req_cnt = 0;
            prev_wr_hs = 1'b0;
        end
        else begin
            if( wr_cfg_start ) begin
                wr_ctrl_cnt = 0;
                stall_rem = ctrl_mode ? 60 : 0;
            end
            cb.wr_csr_req_ready <= stall_rem==0;
            if( stall_rem>0 )
                stall_rem = stall_rem - 1;
            if( cb.wr_csr_req_valid && wr_csr_req_ready ) begin
                if( ctrl_mode ) begin
                    T_check_wr_req(wr_ctrl_cnt,16'h0200,32'h1234_5678);
                    if( wr_ctrl_cnt==0 )
                        wr_first_cycle = cycle_cnt;
                    wr_ctrl_cnt = wr_ctrl_cnt + 1;
                end
                else begin
                if( (wr_req_cnt==1 || wr_req_cnt==3 || wr_req_cnt==4) && !prev_wr_hs )
                    $fatal(1, "CSR package write has a payload bubble idx=%0d", wr_req_cnt);
                case( wr_req_cnt )
                    0: T_check_wr_req(0,16'h0010,32'haaaa_0001);
                    1: T_check_wr_req(1,16'h0024,32'hbbbb_0002);
                    2: T_check_wr_req(2,16'h0040,32'h1000_0000);
                    3: T_check_wr_req(3,16'h0044,32'h1000_0001);
                    4: T_check_wr_req(4,16'h0048,32'h1000_0002);
                    5: T_check_wr_req(5,16'h0030,32'hcccc_0003);
                    default: $fatal(1, "unexpected CSR package write idx=%0d", wr_req_cnt);
                endcase
                wr_req_cnt = wr_req_cnt + 1;
                end
            end
            prev_wr_hs = cb.wr_csr_req_valid && wr_csr_req_ready;
        end
    end
end

//CSR read target with a fixed two-cycle response latency.
initial begin: csr_read_target
    logic pipe_vld0;
    logic pipe_vld1;
    logic [31:0] pipe_addr0;
    logic [31:0] pipe_addr1;
    pipe_vld0 = 1'b0;
    pipe_vld1 = 1'b0;
    pipe_addr0 = '0;
    pipe_addr1 = '0;
    rd_csr_req_ready = 1'b0;
    rd_csr_rsp_rdata = '0;
    rd_csr_rsp_rvalid = 1'b0;
    forever begin
        @(cb);
        if( !rst_n ) begin
            pipe_vld0 = 1'b0;
            pipe_vld1 = 1'b0;
            cb.rd_csr_req_ready <= 1'b0;
            cb.rd_csr_rsp_rvalid <= 1'b0;
            cb.rd_csr_rsp_rdata <= '0;
        end
        else begin
            cb.rd_csr_req_ready <= 1'b1;
            if( rd_cfg_start )
                rd_ctrl_cnt = 0;
            if( ctrl_mode && cb.rd_csr_req_valid && rd_csr_req_ready ) begin
                if( cb.rd_csr_req_addr!==16'h0200 )
                    $fatal(1, "unexpected control-test CSR read");
                rd_ctrl_cnt = rd_ctrl_cnt + 1;
            end
            cb.rd_csr_rsp_rvalid <= pipe_vld1;
            cb.rd_csr_rsp_rdata <= F_csr_rdata(pipe_addr1);
            pipe_vld1 = pipe_vld0;
            pipe_addr1 = pipe_addr0;
            pipe_vld0 = cb.rd_csr_req_valid && rd_csr_req_ready;
            pipe_addr0 = {{(32-CSR_AW){1'b0}},cb.rd_csr_req_addr};
            if( cb.rd_csr_req_valid && rd_csr_req_ready && cb.rd_csr_req_write )
                $fatal(1, "reader emitted CSR write request");
        end
    end
end

//EBUS result sink. Address and byte length select valid words in aligned data beats.
initial begin: result_sink
    logic active;
    logic [EBUS_AW-1:0] result_addr;
    logic [EBUS_AW-1:0] result_end;
    logic [EBUS_AW-1:0] beat_addr;
    integer beat_rem;
    integer wd_stall_rem;
    logic wb_pending;
    active = 1'b0;
    result_addr = '0;
    result_end = '0;
    beat_addr = '0;
    beat_rem = 0;
    wd_stall_rem = 0;
    wb_pending = 1'b0;
    rd_wa_ready = 1'b0;
    rd_wd_ready = 1'b0;
    rd_wb_valid = 1'b0;
    forever begin
        @(cb);
        if( !rst_n ) begin
            active = 1'b0;
            wb_pending = 1'b0;
            wd_stall_rem = 0;
            cb.rd_wa_ready <= 1'b0;
            cb.rd_wd_ready <= 1'b0;
            cb.rd_wb_valid <= 1'b0;
        end
        else begin
            cb.rd_wa_ready <= 1'b1;
            cb.rd_wd_ready <= wd_stall_rem==0;
            cb.rd_wb_valid <= wb_pending;
            if( wb_pending )
                rd_wb_cycle = cycle_cnt;
            wb_pending = 1'b0;
            if( wd_stall_rem!=0 )
                wd_stall_rem = wd_stall_rem - 1;
            if( cb.rd_wa_valid && rd_wa_ready ) begin
                if( active )
                    $fatal(1, "reader EBUS accepts overlapping result write");
                active = 1'b1;
                result_addr = cb.rd_wa_addr;
                result_end = cb.rd_wa_addr + cb.rd_wa_bytelen;
                beat_addr = cb.rd_wa_addr & ~(EBUS_AW'(EBUS_BYTES-1));
                beat_rem = (cb.rd_wa_addr[$clog2(EBUS_BYTES)-1:0] + cb.rd_wa_bytelen + EBUS_BYTES-1)/EBUS_BYTES;
                wd_stall_rem = EBUS_DW>=256 ? 60 : 20;
            end
            if( cb.rd_wd_valid && rd_wd_ready ) begin
                if( !active )
                    $fatal(1, "reader EBUS write data without address");
                for( int i=0; i<EBUS_WORDS; i=i+1 ) begin
                    if( beat_addr+i*4>=result_addr && beat_addr+i*4<result_end )
                        result_mem[10'((beat_addr>>2)+i)] = cb.rd_wd_data[i*32 +: 32];
                end
                if( beat_rem==1 ) begin
                    active = 1'b0;
                    beat_rem = 0;
                    wb_pending = 1'b1;
                end
                else begin
                    beat_addr = beat_addr + EBUS_BYTES;
                    beat_rem = beat_rem - 1;
                end
            end
        end
    end
end

always @(posedge clk) begin
    if( !rst_n ) begin
        result_ram_wr_cnt <= 0;
        result_ram_rd_cnt <= 0;
    end
    else if( !rd_result_ram_ce_n ) begin
        if( !rd_result_ram_we_n )
            result_ram_wr_cnt <= result_ram_wr_cnt + 1;
        else
            result_ram_rd_cnt <= result_ram_rd_cnt + 1;
    end
end

//Main test sequence.
initial begin
    o_done = 1'b0;
    rst_n = 1'b0;
    clear = 1'b0;
    wr_cfg_pkg_addr = 64'h104;
    wr_cfg_pkg_bytelen = 32'd56;
    wr_cfg_start = 1'b0;
    wr_cfg_abort = 1'b0;
    rd_cfg_pkg_addr = 64'h404;
    rd_cfg_pkg_bytelen = 32'd40;
    rd_cfg_start = 1'b0;
    rd_cfg_abort = 1'b0;

    for( int i=0; i<1024; i=i+1 ) begin
        pkg_mem[i] = '0;
        result_mem[i] = '0;
    end

    // Writer block 0: original tail-JUMP coverage.
    pkg_mem['h104>>2] = 32'h0100_0002;
    pkg_mem['h108>>2] = 32'h0000_0010;
    pkg_mem['h10c>>2] = 32'haaaa_0001;
    pkg_mem['h110>>2] = 32'h0000_0024;
    pkg_mem['h114>>2] = 32'hbbbb_0002;
    pkg_mem['h118>>2] = 32'h1100_0003;
    pkg_mem['h11c>>2] = 32'h0000_0040;
    pkg_mem['h120>>2] = 32'h1000_0000;
    pkg_mem['h124>>2] = 32'h1000_0001;
    pkg_mem['h128>>2] = 32'h1000_0002;
    pkg_mem['h12c>>2] = 32'h4400_0000;
    pkg_mem['h130>>2] = 32'h0000_0204;
    pkg_mem['h134>>2] = 32'h0000_0000;
    pkg_mem['h138>>2] = 32'h0000_0014;

    // Writer block 1: one list write and a two-word EXIT header.
    pkg_mem['h204>>2] = 32'h0100_0001;
    pkg_mem['h208>>2] = 32'h0000_0030;
    pkg_mem['h20c>>2] = 32'hcccc_0003;
    pkg_mem['h210>>2] = 32'hf200_0000;
    pkg_mem['h214>>2] = 32'h0000_0000;

    // Reader block 0: 3 independent reads, then jump.
    pkg_mem['h404>>2] = 32'h2300_0003;
    pkg_mem['h408>>2] = 32'h0000_0604;
    pkg_mem['h40c>>2] = 32'h0000_0000;
    pkg_mem['h410>>2] = 32'h0000_0080;
    pkg_mem['h414>>2] = 32'h0000_0014;
    pkg_mem['h418>>2] = 32'h0000_0044;
    pkg_mem['h41c>>2] = 32'h4400_0000;
    pkg_mem['h420>>2] = 32'h0000_0504;
    pkg_mem['h424>>2] = 32'h0000_0000;
    pkg_mem['h428>>2] = 32'h0000_0018;

    // Reader block 1: extended BURST_READ header and EXIT.
    pkg_mem['h504>>2] = 32'h3400_0000 | 32'(READ_BURST_NUM);
    pkg_mem['h508>>2] = 32'h0000_0704;
    pkg_mem['h50c>>2] = 32'h0000_0000;
    pkg_mem['h510>>2] = 32'h0000_0000;
    pkg_mem['h514>>2] = 32'h0000_0100;
    pkg_mem['h518>>2] = 32'hf100_0000;

    // The first JUMP encodes max_num_m1=15. Later JUMP reg_num values are ignored.
    for( int i=0; i<17; i=i+1 ) begin
        pkg_mem[('h800+i*16)>>2] = i==0 ? 32'h4400_000f : 32'h4400_0000;
        pkg_mem[('h804+i*16)>>2] = 32'h0000_0810 + i*16;
        pkg_mem[('h808+i*16)>>2] = 32'h0000_0000;
        pkg_mem[('h80c+i*16)>>2] = 32'h0000_0010;

        pkg_mem[('ha00+i*16)>>2] = i==0 ? 32'h4400_000f : 32'h4400_0000;
        pkg_mem[('ha04+i*16)>>2] = 32'h0000_0a10 + i*16;
        pkg_mem[('ha08+i*16)>>2] = 32'h0000_0000;
        pkg_mem[('ha0c+i*16)>>2] = 32'h0000_0010;
    end

    repeat(5) @(cb);
    cb.rst_n <= 1'b1;
    repeat(3) @(cb);

    cb.wr_cfg_start <= 1'b1;
    @(cb);
    cb.wr_cfg_start <= 1'b0;
    do @(cb); while( !cb.wr_done );
    if( cb.wr_error || cb.wr_error_code!='0 || cb.wr_reg_done_cnt!=32'd6 ||
        cb.wr_jump_cnt!=16'd1 || wr_req_cnt!=6 )
        $fatal(1, "writer status mismatch error=%0b code=%0d done=%0d jump=%0d req=%0d",
               cb.wr_error,cb.wr_error_code,cb.wr_reg_done_cnt,cb.wr_jump_cnt,wr_req_cnt);

    cb.rd_cfg_start <= 1'b1;
    @(cb);
    cb.rd_cfg_start <= 1'b0;
    do @(cb); while( !cb.rd_done );
    if( cb.rd_error || cb.rd_error_code!='0 || cb.rd_reg_done_cnt!=32'(3+READ_BURST_NUM) ||
        cb.rd_jump_cnt!=16'd1 )
        $fatal(1, "reader status mismatch error=%0b code=%0d done=%0d jump=%0d",
               cb.rd_error,cb.rd_error_code,cb.rd_reg_done_cnt,cb.rd_jump_cnt);

    T_check_result('h604>>2,32'h0000_0080);
    T_check_result('h608>>2,F_csr_rdata(32'h80));
    T_check_result('h60c>>2,32'h0000_0014);
    T_check_result('h610>>2,F_csr_rdata(32'h14));
    T_check_result('h614>>2,32'h0000_0044);
    T_check_result('h618>>2,F_csr_rdata(32'h44));
    for( int i=0; i<READ_BURST_NUM; i=i+1 ) begin
        T_check_result(('h704>>2)+i*2,32'h100+i*4);
        T_check_result(('h708>>2)+i*2,F_csr_rdata(32'h100+i*4));
    end

    if( result_ram_wr_cnt==0 || result_ram_rd_cnt==0 )
        $fatal(1, "result SRAM was not exercised wr=%0d rd=%0d",result_ram_wr_cnt,result_ram_rd_cnt);

    cb.wr_cfg_pkg_addr <= 64'h800;
    cb.wr_cfg_pkg_bytelen <= 32'd16;
    cb.wr_cfg_start <= 1'b1;
    @(cb);
    cb.wr_cfg_start <= 1'b0;
    do @(cb); while( !cb.wr_error );
    do @(cb); while( cb.wr_busy );
    if( cb.wr_error_code!=8'd8 || cb.wr_jump_cnt!=16'd16 )
        $fatal(1, "writer jump limit mismatch code=%0d jump=%0d busy=%0b",
               cb.wr_error_code,cb.wr_jump_cnt,cb.wr_busy);

    cb.rd_cfg_pkg_addr <= 64'ha00;
    cb.rd_cfg_pkg_bytelen <= 32'd16;
    cb.rd_cfg_start <= 1'b1;
    @(cb);
    cb.rd_cfg_start <= 1'b0;
    do @(cb); while( !cb.rd_error );
    do @(cb); while( cb.rd_busy );
    if( cb.rd_error_code!=8'd8 || cb.rd_jump_cnt!=16'd16 )
        $fatal(1, "reader jump limit mismatch code=%0d jump=%0d busy=%0b",
               cb.rd_error_code,cb.rd_jump_cnt,cb.rd_busy);

    ctrl_mode = 1'b1;
    for( int side=0; side<2; side=side+1 )
        for( int scenario=0; scenario<12; scenario=scenario+1 )
            T_jump_case(side==1,scenario);
    repeat(3) @(cb);
    o_done = 1'b1;
end

com_csr_pkg_wr #(
    .CSR_AW       (CSR_AW ),
    .EBUS_AW      (EBUS_AW),
    .EBUS_DW      (EBUS_DW),
    .EBUS_LW      (EBUS_LW),
    .EBUS_UW      (EBUS_UW)
)u_com_csr_pkg_wr
(
    .clk                   (clk                ),
    .rst_n                 (rst_n              ),
    .clear                 (clear              ),
    .i_cfg_pkg_addr        (wr_cfg_pkg_addr    ),
    .i_cfg_pkg_bytelen     (wr_cfg_pkg_bytelen),
    .i_cfg_ebus_user       ('0                 ),
    .i_cfg_start           (wr_cfg_start       ),
    .i_cfg_abort           (wr_cfg_abort       ),
    .o_sta_busy            (wr_busy            ),
    .o_pls_done            (wr_done            ),
    .o_pls_error           (wr_error           ),
    .o_sta_error_code      (wr_error_code      ),
    .o_sta_reg_done_cnt    (wr_reg_done_cnt    ),
    .o_sta_jump_cnt        (wr_jump_cnt        ),
    .o_tx_ebus_ra_user     (                   ),
    .o_tx_ebus_ra_addr     (wr_ra_addr         ),
    .o_tx_ebus_ra_bytelen  (wr_ra_bytelen      ),
    .o_tx_ebus_ra_valid    (wr_ra_valid        ),
    .i_tx_ebus_ra_ready    (wr_ra_ready        ),
    .i_tx_ebus_rd_data     (wr_rd_data         ),
    .i_tx_ebus_rd_last     (wr_rd_last         ),
    .i_tx_ebus_rd_valid    (wr_rd_valid        ),
    .o_tx_ebus_rd_ready    (wr_rd_ready        ),
    .o_tx_csr_req_write    (wr_csr_req_write   ),
    .o_tx_csr_req_addr     (wr_csr_req_addr    ),
    .o_tx_csr_req_wdata    (wr_csr_req_wdata   ),
    .o_tx_csr_req_wstrb    (wr_csr_req_wstrb   ),
    .o_tx_csr_req_valid    (wr_csr_req_valid   ),
    .i_tx_csr_req_ready    (wr_csr_req_ready   )
);

com_csr_pkg_rd #(
    .CSR_AW       (CSR_AW      ),
    .EBUS_AW      (EBUS_AW     ),
    .EBUS_DW      (EBUS_DW     ),
    .EBUS_LW      (EBUS_LW     ),
    .EBUS_UW      (EBUS_UW     ),
    .RD_OSD       (4           ),
    .RESULT_DEPTH (RESULT_DEPTH),
    .RAM_RD_DELAY (1           )
)u_com_csr_pkg_rd
(
    .clk                   (clk                ),
    .rst_n                 (rst_n              ),
    .clear                 (clear              ),
    .i_cfg_pkg_addr        (rd_cfg_pkg_addr    ),
    .i_cfg_pkg_bytelen     (rd_cfg_pkg_bytelen),
    .i_cfg_ebus_user       ('0                 ),
    .i_cfg_start           (rd_cfg_start       ),
    .i_cfg_abort           (rd_cfg_abort       ),
    .o_sta_busy            (rd_busy            ),
    .o_pls_done            (rd_done            ),
    .o_pls_error           (rd_error           ),
    .o_sta_error_code      (rd_error_code      ),
    .o_sta_reg_done_cnt    (rd_reg_done_cnt    ),
    .o_sta_jump_cnt        (rd_jump_cnt        ),
    .o_tx_ebus_ra_user     (                   ),
    .o_tx_ebus_ra_addr     (rd_ra_addr         ),
    .o_tx_ebus_ra_bytelen  (rd_ra_bytelen      ),
    .o_tx_ebus_ra_valid    (rd_ra_valid        ),
    .i_tx_ebus_ra_ready    (rd_ra_ready        ),
    .i_tx_ebus_rd_data     (rd_rd_data         ),
    .i_tx_ebus_rd_last     (rd_rd_last         ),
    .i_tx_ebus_rd_valid    (rd_rd_valid        ),
    .o_tx_ebus_rd_ready    (rd_rd_ready        ),
    .o_tx_ebus_wa_user     (                   ),
    .o_tx_ebus_wa_addr     (rd_wa_addr         ),
    .o_tx_ebus_wa_bytelen  (rd_wa_bytelen      ),
    .o_tx_ebus_wa_valid    (rd_wa_valid        ),
    .i_tx_ebus_wa_ready    (rd_wa_ready        ),
    .o_tx_ebus_wd_data     (rd_wd_data         ),
    .o_tx_ebus_wd_valid    (rd_wd_valid        ),
    .i_tx_ebus_wd_ready    (rd_wd_ready        ),
    .i_tx_ebus_wb_valid    (rd_wb_valid        ),
    .o_tx_csr_req_write    (rd_csr_req_write   ),
    .o_tx_csr_req_addr     (rd_csr_req_addr    ),
    .o_tx_csr_req_wdata    (rd_csr_req_wdata   ),
    .o_tx_csr_req_wstrb    (rd_csr_req_wstrb   ),
    .o_tx_csr_req_valid    (rd_csr_req_valid   ),
    .i_tx_csr_req_ready    (rd_csr_req_ready   ),
    .i_tx_csr_rsp_rdata    (rd_csr_rsp_rdata   ),
    .i_tx_csr_rsp_rvalid   (rd_csr_rsp_rvalid  ),
    .o_result_ram_ce_n     (rd_result_ram_ce_n    ),
    .o_result_ram_we_n     (rd_result_ram_we_n    ),
    .o_result_ram_addr     (rd_result_ram_addr    ),
    .o_result_ram_wr_data  (rd_result_ram_wr_data ),
    .i_result_ram_rd_data  (rd_result_ram_rd_data )
);

com_spram_shell #(
    .DATA_W (128           ),
    .DEPTH  (RESULT_DEPTH/2),
    .STRB_W (1             )
)u_com_spram_shell_result
(
    .clk            (clk                   ), //i
    .i_cfg_mem_ctrl ('0                    ), //i
    .i_ce_n         (rd_result_ram_ce_n    ), //i
    .i_we_n         (rd_result_ram_we_n    ), //i
    .i_addr         (rd_result_ram_addr    ), //i
    .i_wr_data      (rd_result_ram_wr_data ), //i
    .o_rd_data      (rd_result_ram_rd_data )  //o
);

endmodule
