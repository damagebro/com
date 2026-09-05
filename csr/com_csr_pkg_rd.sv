module com_csr_pkg_rd #(
    parameter CSR_AW       = 16,  //range=[1:32]
    parameter EBUS_AW      = 64,  //range=[8:64]
    parameter EBUS_DW      = 256, //range=[32::2^n]
    parameter EBUS_LW      = 32,  //range=[20:EBUS_AW]
    parameter EBUS_UW      = 1,  //range=[1::]
    parameter RD_OSD       = 8,  //range=[1:32]
    parameter RESULT_DEPTH = 32, //range=[4::2]
    parameter RAM_RD_DELAY = 1,  //range=[1:16]
    localparam RESULT_RAM_DEPTH = RESULT_DEPTH/2,
    localparam RESULT_RAM_AW    = $clog2(RESULT_RAM_DEPTH>2?RESULT_RAM_DEPTH:2)//,
)
(
    input  wire                     clk                    ,
    input  wire                     rst_n                  ,
    input  wire                     clear                  ,

    input  wire [EBUS_AW-1:0]       i_cfg_pkg_addr         ,
    input  wire [EBUS_LW-1:0]       i_cfg_pkg_bytelen      ,
    input  wire [EBUS_UW-1:0]       i_cfg_ebus_user        ,
    input  wire                     i_cfg_start             ,
    input  wire                     i_cfg_abort             ,
    output wire                     o_sta_busy              ,
    output wire                     o_pls_done              ,
    output wire                     o_pls_error             ,
    output wire [7:0]               o_sta_error_code        ,
    output wire [31:0]              o_sta_reg_done_cnt      ,
    output wire [15:0]              o_sta_jump_cnt          ,

    output wire [EBUS_UW-1:0]       o_tx_ebus_ra_user       ,
    output wire [EBUS_AW-1:0]       o_tx_ebus_ra_addr       ,
    output wire [EBUS_LW-1:0]       o_tx_ebus_ra_bytelen    ,
    output wire                     o_tx_ebus_ra_valid      ,
    input  wire                     i_tx_ebus_ra_ready      ,
    input  wire [EBUS_DW-1:0]       i_tx_ebus_rd_data       ,
    input  wire                     i_tx_ebus_rd_last       ,
    input  wire                     i_tx_ebus_rd_valid      ,
    output wire                     o_tx_ebus_rd_ready      ,

    output wire [EBUS_UW-1:0]       o_tx_ebus_wa_user       ,
    output wire [EBUS_AW-1:0]       o_tx_ebus_wa_addr       ,
    output wire [EBUS_LW-1:0]       o_tx_ebus_wa_bytelen    ,
    output wire                     o_tx_ebus_wa_valid      ,
    input  wire                     i_tx_ebus_wa_ready      ,
    output wire [EBUS_DW-1:0]       o_tx_ebus_wd_data       ,
    output wire                     o_tx_ebus_wd_valid      ,
    input  wire                     i_tx_ebus_wd_ready      ,
    input  wire                     i_tx_ebus_wb_valid      ,

    output wire                     o_tx_csr_req_write      ,
    output wire [CSR_AW-1:0]        o_tx_csr_req_addr       ,
    output wire [31:0]              o_tx_csr_req_wdata      ,
    output wire [3:0]               o_tx_csr_req_wstrb      ,
    output wire                     o_tx_csr_req_valid      ,
    input  wire                     i_tx_csr_req_ready      ,
    input  wire [31:0]              i_tx_csr_rsp_rdata      ,
    input  wire                     i_tx_csr_rsp_rvalid     ,

    output wire                     o_result_ram_ce_n       ,
    output wire                     o_result_ram_we_n       ,
    output wire [RESULT_RAM_AW-1:0] o_result_ram_addr       ,
    output wire [127:0]             o_result_ram_wr_data    ,
    input  wire [127:0]             i_result_ram_rd_data    //,
);

//localparam-----------------------------------------------------------------
localparam EBUS_WN          = EBUS_DW/32;
localparam EBUS_WN_L2       = $clog2(EBUS_WN>1?EBUS_WN:2);
localparam RESULT_CW        = $clog2(RESULT_DEPTH+1);
localparam RESULT_OUT_DEPTH = RAM_RD_DELAY+3;

typedef enum logic [3:0] {
    eIDLE        = 4'd0,
    eRA          = 4'd1,
    eHEADER      = 4'd2,
    eHEADER_EXTD = 4'd3,
    eWA          = 4'd4,
    eLR_ADDR     = 4'd5,
    eBR_ADDR     = 4'd6,
    eBR_ISSUE    = 4'd7,
    eWAIT_RSP    = 4'd8,
    eJUMP        = 4'd9,
    eERROR       = 4'd10
} state_t;

localparam [3:0] OP_LIST_READ  = 4'd2;
localparam [3:0] OP_BURST_READ = 4'd3;
localparam [3:0] OP_JUMP       = 4'd4;
localparam [3:0] OP_EXIT       = 4'd15;

localparam [7:0] ERR_NONE       = 8'd0;
localparam [7:0] ERR_BAD_OPCODE = 8'd1;
localparam [7:0] ERR_BAD_HEADER = 8'd2;
localparam [7:0] ERR_BAD_REGNUM = 8'd3;
localparam [7:0] ERR_BAD_BLOCK  = 8'd4;
localparam [7:0] ERR_BAD_ALIGN  = 8'd5;
localparam [7:0] ERR_START_BUSY = 8'd6;
localparam [7:0] ERR_ABORTED    = 8'd7;
localparam [7:0] ERR_JUMP_LIMIT = 8'd8;
localparam [7:0] ERR_DUP_JUMP   = 8'd9;
//signal declare-------------------------------------------------------------
state_t                    r_state;
reg                        r_busy;
reg                        r_pls_done;
reg                        r_pls_error;
reg  [7:0]                 r_error_code;
reg  [31:0]                r_reg_done_cnt;
reg  [15:0]                r_jump_cnt;
reg  [7:0]                 r_jump_max_num_m1;

reg  [EBUS_AW-1:0]         r_block_addr;
reg  [EBUS_LW-1:0]         r_block_bytesize;
reg  [EBUS_LW-1:0]         r_block_word_rem;
reg                        r_block_active;
reg  [EBUS_LW-1:0]         r_ebus_word_rem;
reg                        r_first_beat_flag;
reg                        r_beat_vld;
reg  [EBUS_DW-1:0]         r_beat_data;
reg  [EBUS_WN_L2-1:0]      r_beat_lane;

reg  [3:0]                 r_opcode;
reg  [3:0]                 r_extd_rem;
reg  [3:0]                 r_extd_idx;
reg  [15:0]                r_entry_rem;
reg  [15:0]                r_entry_num;
reg  [31:0]                r_csr_addr;
reg  [63:0]                r_result_addr;
reg  [63:0]                r_jump_addr;
reg  [31:0]                r_jump_bytesize;
reg                        r_jump_pending;
reg                        r_prefetch_req;
reg                        r_prefetch_sent;

reg  [EBUS_LW:0]           w_instr_words;
reg                        w_header_bad;
reg  [7:0]                 w_header_error_code;
reg  [RESULT_CW-1:0]       r_result_pend_cnt;
reg  [16:0]                r_result_word_rem;
reg                        r_pair_data_phase;
reg  [EBUS_DW-1:0]         r_wd_data;
reg                        r_wd_valid;
reg  [EBUS_WN_L2-1:0]      r_pack_lane;
reg                        r_wb_seen;
reg                        r_result_active;

wire [3:0]                 header_opcode;
wire [3:0]                 header_wordsize;
wire [15:0]                header_reg_num;
wire                       ebus_ra_hs;
wire                       ebus_rd_hs;
wire                       ebus_wa_hs;
wire                       ebus_wd_hs;
wire                       csr_req_hs;
wire                       word_vld;
wire [31:0]                word_data;
wire                       word_take;
wire [EBUS_WN_L2-1:0]      load_lane;
wire [EBUS_WN_L2:0]        load_word_avl;
wire [EBUS_WN_L2:0]        ebus_word_take_num;
wire                       expected_rd_last;
wire                       beat_last_error;
wire                       start_align_error;
wire                       result_align_error;
wire                       jump_align_error;
wire                       csr_addr_align_error;
wire                       header_error_event;
wire                       result_error_event;
wire                       done_event;
wire                       jump_event;
wire                       jump_limit_error;
wire                       jump_register;
wire                       block_start;
wire                       block_end_error;
wire                       prefetch_ra_hs;
wire                       prefetch_drain_hs;
wire                       error_drain_done;
wire [EBUS_LW-1:0]         block_start_bytelen;
wire                       read_credit_avl;
wire [CSR_AW-1:0]          csr_req_addr_sel;
wire [18:0]                result_bytelen;
wire                       pack_word_vld;
wire [31:0]                pack_word_data;
wire                       pack_word_hs;
wire                       pack_entry_done;
wire                       read_result_done;

//instance signal---
wire                       u_meta_i_wr_en;
wire [31:0]                u_meta_i_wr_data;
wire                       u_meta_o_wr_full;
wire                       u_meta_i_rd_en;
wire [31:0]                u_meta_o_rd_data;
wire                       u_meta_o_rd_empty;

wire                       u_result_i_wr_en;
wire [63:0]                u_result_i_wr_data;
wire                       u_result_o_wr_full;
wire                       u_result_i_rd_en;
wire [63:0]                u_result_o_rd_data;
wire                       u_result_o_rd_empty;
//statement------------------------------------------------------------------
//output assign---
assign o_sta_busy = r_busy;
assign o_pls_done = r_pls_done;
assign o_pls_error = r_pls_error;
assign o_sta_error_code = r_error_code;
assign o_sta_reg_done_cnt = r_reg_done_cnt;
assign o_sta_jump_cnt = r_jump_cnt;

assign o_tx_ebus_ra_user = i_cfg_ebus_user;
assign o_tx_ebus_ra_addr = r_prefetch_req ? EBUS_AW'(r_jump_addr) : r_block_addr;
assign o_tx_ebus_ra_bytelen = r_prefetch_req ? EBUS_LW'(r_jump_bytesize) : r_block_bytesize;
assign o_tx_ebus_ra_valid = r_state==eRA || r_prefetch_req;
assign o_tx_ebus_rd_ready = (r_block_active && r_ebus_word_rem!='0 && !r_beat_vld) ||
                           (r_state==eERROR && r_prefetch_sent);

assign o_tx_ebus_wa_user = i_cfg_ebus_user;
assign o_tx_ebus_wa_addr = EBUS_AW'(r_result_addr);
assign o_tx_ebus_wa_bytelen = EBUS_LW'(result_bytelen);
assign o_tx_ebus_wa_valid = r_state==eWA && !result_align_error;
assign o_tx_ebus_wd_data = r_wd_data;
assign o_tx_ebus_wd_valid = r_wd_valid;

assign o_tx_csr_req_write = 1'b0;
assign csr_req_addr_sel = r_state==eLR_ADDR ? word_data[CSR_AW-1:0] : r_csr_addr[CSR_AW-1:0];
assign o_tx_csr_req_addr = csr_req_addr_sel;
assign o_tx_csr_req_wdata = '0;
assign o_tx_csr_req_wstrb = '0;
assign o_tx_csr_req_valid = (r_state==eLR_ADDR && word_vld && !csr_addr_align_error && read_credit_avl) ||
                            (r_state==eBR_ISSUE && read_credit_avl);

//body---
assign ebus_ra_hs = o_tx_ebus_ra_valid && i_tx_ebus_ra_ready;
assign ebus_rd_hs = i_tx_ebus_rd_valid && o_tx_ebus_rd_ready && !r_prefetch_sent;
assign prefetch_ra_hs = ebus_ra_hs && r_prefetch_req;
assign prefetch_drain_hs = r_state==eERROR && r_prefetch_sent && i_tx_ebus_rd_valid && o_tx_ebus_rd_ready;
assign ebus_wa_hs = o_tx_ebus_wa_valid && i_tx_ebus_wa_ready;
assign ebus_wd_hs = o_tx_ebus_wd_valid && i_tx_ebus_wd_ready;
assign csr_req_hs = o_tx_csr_req_valid && i_tx_csr_req_ready;

assign word_vld = r_beat_vld && r_block_word_rem!='0;
assign word_data = r_beat_data[r_beat_lane*32 +: 32];
assign word_take = word_vld && (r_state==eHEADER || r_state==eHEADER_EXTD || r_state==eBR_ADDR ||
                   r_state==eERROR) || (csr_req_hs && r_state==eLR_ADDR);

assign header_opcode = word_data[31:28];
assign header_wordsize = word_data[27:24];
assign header_reg_num = word_data[15:0];

always @* begin
    w_instr_words = '0;
    w_header_bad = 1'b0;
    w_header_error_code = ERR_NONE;
    case( header_opcode )
        OP_LIST_READ: begin
            w_instr_words = (EBUS_LW+1)'(header_wordsize) + (EBUS_LW+1)'(header_reg_num);
            if( header_wordsize<4'd3 ) begin
                w_header_bad = 1'b1;
                w_header_error_code = ERR_BAD_HEADER;
            end
            else if( header_reg_num=='0 ) begin
                w_header_bad = 1'b1;
                w_header_error_code = ERR_BAD_REGNUM;
            end
        end
        OP_BURST_READ: begin
            w_instr_words = (EBUS_LW+1)'(header_wordsize) + 1'b1;
            if( header_wordsize<4'd3 ) begin
                w_header_bad = 1'b1;
                w_header_error_code = ERR_BAD_HEADER;
            end
            else if( header_reg_num=='0 ) begin
                w_header_bad = 1'b1;
                w_header_error_code = ERR_BAD_REGNUM;
            end
        end
        OP_JUMP: begin
            w_instr_words = (EBUS_LW+1)'(header_wordsize);
            if( header_wordsize<4'd4 ) begin
                w_header_bad = 1'b1;
                w_header_error_code = ERR_BAD_HEADER;
            end
            else if( header_reg_num[15:8]!='0 ) begin
                w_header_bad = 1'b1;
                w_header_error_code = ERR_BAD_REGNUM;
            end
        end
        OP_EXIT: begin
            w_instr_words = (EBUS_LW+1)'(header_wordsize);
            if( header_wordsize<4'd1 ) begin
                w_header_bad = 1'b1;
                w_header_error_code = ERR_BAD_HEADER;
            end
            else if( header_reg_num!='0 ) begin
                w_header_bad = 1'b1;
                w_header_error_code = ERR_BAD_REGNUM;
            end
        end
        default: begin
            w_header_bad = 1'b1;
            w_header_error_code = ERR_BAD_OPCODE;
        end
    endcase
    if( !w_header_bad && w_instr_words>{1'b0,r_block_word_rem} ) begin
        w_header_bad = 1'b1;
        w_header_error_code = ERR_BAD_BLOCK;
    end
    if( !w_header_bad && header_opcode==OP_EXIT &&
        w_instr_words!={1'b0,r_block_word_rem} ) begin
        w_header_bad = 1'b1;
        w_header_error_code = ERR_BAD_BLOCK;
    end
    if( !w_header_bad && r_jump_pending && (header_opcode==OP_JUMP || header_opcode==OP_EXIT) ) begin
        w_header_bad = 1'b1;
        w_header_error_code = header_opcode==OP_JUMP ? ERR_DUP_JUMP : ERR_BAD_BLOCK;
    end
end

assign load_lane = r_first_beat_flag ? EBUS_WN_L2'(r_block_addr>>2) : '0;
assign load_word_avl = (EBUS_WN_L2+1)'(EBUS_WN) - {1'b0,load_lane};
assign ebus_word_take_num = r_ebus_word_rem<=EBUS_LW'(load_word_avl) ?
                            (EBUS_WN_L2+1)'(r_ebus_word_rem) : load_word_avl;
assign expected_rd_last = r_ebus_word_rem<=EBUS_LW'(load_word_avl);
assign beat_last_error = ebus_rd_hs && (i_tx_ebus_rd_last!=expected_rd_last);
assign start_align_error = i_cfg_pkg_bytelen<EBUS_LW'(4) || |i_cfg_pkg_bytelen[1:0] ||
                           |i_cfg_pkg_addr[1:0];
assign result_align_error = |r_result_addr[1:0] || |(r_result_addr>>EBUS_AW);
assign jump_align_error = r_jump_bytesize<32'd4 || |r_jump_bytesize[1:0] || |r_jump_addr[1:0] ||
                          |(r_jump_addr>>EBUS_AW) || |(r_jump_bytesize>>EBUS_LW);
assign csr_addr_align_error = word_vld && (r_state==eLR_ADDR || r_state==eBR_ADDR) && |word_data[1:0];
assign header_error_event = r_state==eHEADER && word_vld && w_header_bad;
assign result_error_event = r_state==eWA && result_align_error;
assign done_event = word_take && ((r_state==eHEADER && header_opcode==OP_EXIT &&
                    header_wordsize==4'd1 && !w_header_bad) ||
                    (r_state==eHEADER_EXTD && r_extd_rem==1 && r_opcode==OP_EXIT));
assign jump_limit_error = r_state==eJUMP && r_jump_cnt>{8'b0,r_jump_max_num_m1};
assign jump_register = r_state==eJUMP && !jump_align_error && !jump_limit_error;
assign jump_event = r_state==eHEADER && !r_block_active && r_jump_pending && r_prefetch_sent &&
                    !i_cfg_abort;
assign block_start = (ebus_ra_hs && !r_prefetch_req) || jump_event;
assign block_start_bytelen = jump_event ? EBUS_LW'(r_jump_bytesize) : r_block_bytesize;
assign block_end_error = r_state==eHEADER && !r_block_active && !r_jump_pending;
assign error_drain_done = !r_block_active && !r_prefetch_req && !r_prefetch_sent &&
                          r_result_pend_cnt=='0 && !r_result_active && !r_wd_valid;

assign result_bytelen = {r_entry_num,3'b0};
assign read_credit_avl = r_result_pend_cnt<RESULT_CW'(RESULT_DEPTH) && !u_meta_o_wr_full;
assign pack_word_vld = !u_result_o_rd_empty && r_result_word_rem!='0;
assign pack_word_data = r_pair_data_phase ? u_result_o_rd_data[31:0] : u_result_o_rd_data[63:32];
assign pack_word_hs = pack_word_vld && !r_wd_valid;
assign pack_entry_done = pack_word_hs && r_pair_data_phase;
assign read_result_done = r_state==eWAIT_RSP && r_result_word_rem=='0 && !r_wd_valid &&
                          (r_wb_seen || i_tx_ebus_wb_valid);

//state
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_state <= eIDLE;
        r_busy <= 1'b0;
    end
    else if( clear ) begin
        r_state <= eIDLE;
        r_busy <= 1'b0;
    end
    else if( i_cfg_abort && r_busy ) begin
        r_state <= eERROR;
        r_busy <= 1'b1;
    end
    else if( beat_last_error || csr_addr_align_error || block_end_error )
        r_state <= eERROR;
    else begin
        case( r_state )
            eIDLE: begin
                if( i_cfg_start && !start_align_error ) begin
                    r_state <= eRA;
                    r_busy <= 1'b1;
                end
            end
            eRA: begin
                if( ebus_ra_hs )
                    r_state <= eHEADER;
            end
            eHEADER: begin
                if( jump_event )
                    r_state <= eHEADER;
                else if( word_vld ) begin
                    if( w_header_bad )
                        r_state <= eERROR;
                    else if( header_wordsize>4'd1 )
                        r_state <= eHEADER_EXTD;
                    else if( header_opcode==OP_EXIT ) begin
                        r_state <= eIDLE;
                        r_busy <= 1'b0;
                    end
                    else
                        r_state <= eERROR;
                end
            end
            eHEADER_EXTD: begin
                if( word_vld && r_extd_rem==1 ) begin
                    case( r_opcode )
                        OP_LIST_READ,
                        OP_BURST_READ: r_state <= eWA;
                        OP_JUMP:       r_state <= eJUMP;
                        OP_EXIT: begin
                            r_state <= eIDLE;
                            r_busy <= 1'b0;
                        end
                        default: r_state <= eERROR;
                    endcase
                end
            end
            eWA: begin
                if( result_align_error )
                    r_state <= eERROR;
                else if( ebus_wa_hs )
                    r_state <= r_opcode==OP_LIST_READ ? eLR_ADDR : eBR_ADDR;
            end
            eLR_ADDR: begin
                if( csr_req_hs && r_entry_rem==1 )
                    r_state <= eWAIT_RSP;
            end
            eBR_ADDR: begin
                if( word_vld )
                    r_state <= eBR_ISSUE;
            end
            eBR_ISSUE: begin
                if( csr_req_hs && r_entry_rem==1 )
                    r_state <= eWAIT_RSP;
            end
            eWAIT_RSP: begin
                if( read_result_done )
                    r_state <= eHEADER;
            end
            eJUMP: begin
                if( jump_align_error || jump_limit_error )
                    r_state <= eERROR;
                else
                    r_state <= eHEADER;
            end
            eERROR: begin
                if( error_drain_done ) begin
                    r_state <= eIDLE;
                    r_busy <= 1'b0;
                end
            end
            default: begin
                r_state <= eIDLE;
                r_busy <= 1'b0;
            end
        endcase
    end
end

//block command
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_block_addr <= '0;
        r_block_bytesize <= '0;
    end
    else if( clear ) begin
        r_block_addr <= '0;
        r_block_bytesize <= '0;
    end
    else if( r_state==eIDLE && i_cfg_start && !start_align_error ) begin
        r_block_addr <= i_cfg_pkg_addr;
        r_block_bytesize <= i_cfg_pkg_bytelen;
    end
    else if( jump_event ) begin
        r_block_addr <= EBUS_AW'(r_jump_addr);
        r_block_bytesize <= EBUS_LW'(r_jump_bytesize);
    end
end

//block word count
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_block_word_rem <= '0;
        r_block_active <= 1'b0;
    end
    else if( clear ) begin
        r_block_word_rem <= '0;
        r_block_active <= 1'b0;
    end
    else if( block_start ) begin
        r_block_word_rem <= block_start_bytelen>>2;
        r_block_active <= 1'b1;
    end
    else if( word_take ) begin
        r_block_word_rem <= r_block_word_rem - 1'b1;
        if( r_block_word_rem==1 )
            r_block_active <= 1'b0;
    end
end

//EBUS receive word count
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_ebus_word_rem <= '0;
    else if( clear )
        r_ebus_word_rem <= '0;
    else if( block_start )
        r_ebus_word_rem <= block_start_bytelen>>2;
    else if( ebus_rd_hs )
        r_ebus_word_rem <= r_ebus_word_rem - ebus_word_take_num;
end

//first beat flag
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_first_beat_flag <= 1'b0;
    else if( clear )
        r_first_beat_flag <= 1'b0;
    else if( block_start )
        r_first_beat_flag <= 1'b1;
    else if( ebus_rd_hs )
        r_first_beat_flag <= 1'b0;
end

//beat valid
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_beat_vld <= 1'b0;
    else if( clear || block_start )
        r_beat_vld <= 1'b0;
    else if( ebus_rd_hs )
        r_beat_vld <= 1'b1;
    else if( word_take && (r_block_word_rem==1 || r_beat_lane==EBUS_WN_L2'(EBUS_WN-1)) )
        r_beat_vld <= 1'b0;
end

//beat data
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_beat_data <= '0;
    else if( clear )
        r_beat_data <= '0;
    else if( ebus_rd_hs )
        r_beat_data <= i_tx_ebus_rd_data;
end

//beat lane
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_beat_lane <= '0;
    else if( clear || block_start )
        r_beat_lane <= '0;
    else if( ebus_rd_hs )
        r_beat_lane <= load_lane;
    else if( word_take && r_block_word_rem!=1 ) begin
        if( r_beat_lane==EBUS_WN_L2'(EBUS_WN-1) )
            r_beat_lane <= '0;
        else
            r_beat_lane <= r_beat_lane + 1'b1;
    end
end

//opcode
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_opcode <= '0;
    else if( clear )
        r_opcode <= '0;
    else if( r_state==eHEADER && word_vld && !w_header_bad )
        r_opcode <= header_opcode;
end

//extension count
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_extd_rem <= '0;
        r_extd_idx <= '0;
    end
    else if( clear ) begin
        r_extd_rem <= '0;
        r_extd_idx <= '0;
    end
    else if( r_state==eHEADER && word_vld && !w_header_bad ) begin
        r_extd_rem <= header_wordsize - 1'b1;
        r_extd_idx <= '0;
    end
    else if( r_state==eHEADER_EXTD && word_vld ) begin
        r_extd_rem <= r_extd_rem - 1'b1;
        r_extd_idx <= r_extd_idx + 1'b1;
    end
end

//entry count
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_entry_rem <= '0;
        r_entry_num <= '0;
    end
    else if( clear ) begin
        r_entry_rem <= '0;
        r_entry_num <= '0;
    end
    else if( r_state==eHEADER && word_vld && !w_header_bad ) begin
        r_entry_rem <= header_reg_num;
        r_entry_num <= header_reg_num;
    end
    else if( csr_req_hs )
        r_entry_rem <= r_entry_rem - 1'b1;
end

//CSR address
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_csr_addr <= '0;
    else if( clear )
        r_csr_addr <= '0;
    else if( r_state==eBR_ADDR && word_vld )
        r_csr_addr <= word_data;
    else if( r_state==eBR_ISSUE && csr_req_hs )
        r_csr_addr <= r_csr_addr + 32'd4;
end

//result address
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_result_addr <= '0;
    else if( clear )
        r_result_addr <= '0;
    else if( r_state==eHEADER_EXTD && word_vld && (r_opcode==OP_LIST_READ || r_opcode==OP_BURST_READ) ) begin
        if( r_extd_idx==0 )
            r_result_addr[31:0] <= word_data;
        else if( r_extd_idx==1 )
            r_result_addr[63:32] <= word_data;
    end
end

//jump command
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_jump_addr <= '0;
        r_jump_bytesize <= '0;
    end
    else if( clear ) begin
        r_jump_addr <= '0;
        r_jump_bytesize <= '0;
    end
    else if( r_state==eHEADER_EXTD && word_vld && r_opcode==OP_JUMP ) begin
        if( r_extd_idx==0 )
            r_jump_addr[31:0] <= word_data;
        else if( r_extd_idx==1 )
            r_jump_addr[63:32] <= word_data;
        else if( r_extd_idx==2 )
            r_jump_bytesize <= word_data;
    end
end

//JUMP describes the successor; commit waits for all current-block operations.
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_jump_pending <= 1'b0;
    else if( clear || block_start )
        r_jump_pending <= 1'b0;
    else if( jump_register )
        r_jump_pending <= 1'b1;
end

//Hold an offered RA through backpressure, including error/abort drain.
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_prefetch_req <= 1'b0;
    else if( clear || prefetch_ra_hs )
        r_prefetch_req <= 1'b0;
    else if( r_jump_pending && r_ebus_word_rem=='0 && !r_prefetch_sent && r_state!=eERROR &&
             r_state!=eIDLE && r_state!=eRA && !i_cfg_abort && !header_error_event &&
             !csr_addr_align_error && !beat_last_error && !result_error_event )
        r_prefetch_req <= 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_prefetch_sent <= 1'b0;
    else if( clear || jump_event || (prefetch_drain_hs && i_tx_ebus_rd_last) )
        r_prefetch_sent <= 1'b0;
    else if( prefetch_ra_hs )
        r_prefetch_sent <= 1'b1;
end

//jump limit
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_jump_max_num_m1 <= '0;
    else if( clear || (r_state==eIDLE && i_cfg_start) )
        r_jump_max_num_m1 <= '0;
    else if( r_state==eHEADER && word_vld && !w_header_bad && header_opcode==OP_JUMP && r_jump_cnt=='0 )
        r_jump_max_num_m1 <= header_reg_num[7:0];
end

//result outstanding reserve
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_result_pend_cnt <= '0;
    else if( clear || (r_state==eIDLE && i_cfg_start) )
        r_result_pend_cnt <= '0;
    else begin
        case( {csr_req_hs,pack_entry_done} )
            2'b10: r_result_pend_cnt <= r_result_pend_cnt + 1'b1;
            2'b01: r_result_pend_cnt <= r_result_pend_cnt - 1'b1;
            default: r_result_pend_cnt <= r_result_pend_cnt;
        endcase
    end
end

//result word serializer and EBUS packer
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_result_word_rem <= '0;
        r_pair_data_phase <= 1'b0;
        r_wd_data <= '0;
        r_wd_valid <= 1'b0;
        r_pack_lane <= '0;
    end
    else if( clear ) begin
        r_result_word_rem <= '0;
        r_pair_data_phase <= 1'b0;
        r_wd_data <= '0;
        r_wd_valid <= 1'b0;
        r_pack_lane <= '0;
    end
    else if( ebus_wa_hs ) begin
        r_result_word_rem <= {r_entry_num,1'b0};
        r_pair_data_phase <= 1'b0;
        r_wd_data <= '0;
        r_wd_valid <= 1'b0;
        r_pack_lane <= EBUS_WN_L2'(r_result_addr>>2);
    end
    else begin
        if( ebus_wd_hs ) begin
            r_wd_data <= '0;
            r_wd_valid <= 1'b0;
        end
        if( pack_word_hs ) begin
            r_wd_data[r_pack_lane*32 +: 32] <= pack_word_data;
            r_result_word_rem <= r_result_word_rem - 1'b1;
            r_pair_data_phase <= !r_pair_data_phase;
            if( r_pack_lane==EBUS_WN_L2'(EBUS_WN-1) || r_result_word_rem==1 ) begin
                r_wd_valid <= 1'b1;
                r_pack_lane <= '0;
            end
            else
                r_pack_lane <= r_pack_lane + 1'b1;
        end
    end
end

//Track result completion through a package-error drain.
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_result_active <= 1'b0;
    else if( clear )
        r_result_active <= 1'b0;
    else if( ebus_wa_hs )
        r_result_active <= 1'b1;
    else if( i_tx_ebus_wb_valid )
        r_result_active <= 1'b0;
end

//write response capture
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_wb_seen <= 1'b0;
    else if( clear || ebus_wa_hs )
        r_wb_seen <= 1'b0;
    else if( i_tx_ebus_wb_valid )
        r_wb_seen <= 1'b1;
end

//status pulse
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_pls_done <= 1'b0;
        r_pls_error <= 1'b0;
    end
    else if( clear ) begin
        r_pls_done <= 1'b0;
        r_pls_error <= 1'b0;
    end
    else begin
        r_pls_done <= done_event;
        r_pls_error <= (r_state==eIDLE && i_cfg_start && start_align_error) ||
                       (r_busy && i_cfg_start) || (i_cfg_abort && r_busy) || beat_last_error ||
                       csr_addr_align_error || header_error_event || result_error_event || block_end_error ||
                       (r_state==eJUMP && (jump_align_error || jump_limit_error));
    end
end

//error code
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_error_code <= ERR_NONE;
    else if( clear )
        r_error_code <= ERR_NONE;
    else if( r_state==eIDLE && i_cfg_start )
        r_error_code <= start_align_error ? ERR_BAD_ALIGN : ERR_NONE;
    else if( r_error_code==ERR_NONE ) begin
        if( r_busy && i_cfg_start )
            r_error_code <= ERR_START_BUSY;
        else if( i_cfg_abort && r_busy )
            r_error_code <= ERR_ABORTED;
        else if( beat_last_error || block_end_error )
            r_error_code <= ERR_BAD_BLOCK;
        else if( csr_addr_align_error )
            r_error_code <= ERR_BAD_ALIGN;
        else if( header_error_event )
            r_error_code <= w_header_error_code;
        else if( result_error_event || (r_state==eJUMP && jump_align_error) )
            r_error_code <= ERR_BAD_ALIGN;
        else if( jump_limit_error )
            r_error_code <= ERR_JUMP_LIMIT;
    end
end

//status counter
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_reg_done_cnt <= '0;
    else if( clear || (r_state==eIDLE && i_cfg_start) )
        r_reg_done_cnt <= '0;
    else if( i_tx_csr_rsp_rvalid && r_reg_done_cnt!='1 )
        r_reg_done_cnt <= r_reg_done_cnt + 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_jump_cnt <= '0;
    else if( clear || (r_state==eIDLE && i_cfg_start) )
        r_jump_cnt <= '0;
    else if( jump_event && r_jump_cnt!='1 )
        r_jump_cnt <= r_jump_cnt + 1'b1;
end

//instance-------------------------------------------------------------------
assign u_meta_i_wr_en = csr_req_hs;
assign u_meta_i_wr_data = r_state==eLR_ADDR ? word_data : r_csr_addr;
assign u_meta_i_rd_en = i_tx_csr_rsp_rvalid && !u_meta_o_rd_empty;
com_sync_fifo_reg #(
    .DW    (32    ),
    .DEPTH (RD_OSD)
)u_com_sync_fifo_reg_meta
(
    .clk           (clk               ), //i
    .rst_n         (rst_n             ), //i
    .clear         (clear             ), //i
    .i_wr_en       (u_meta_i_wr_en    ), //i
    .i_wr_data     (u_meta_i_wr_data  ), //i
    .o_wr_full     (u_meta_o_wr_full  ), //o
    .i_rd_en       (u_meta_i_rd_en    ), //i
    .o_rd_data     (u_meta_o_rd_data  ), //o
    .o_rd_empty    (u_meta_o_rd_empty ), //o
    .o_water_level (                  )  //o
);

assign u_result_i_wr_en = i_tx_csr_rsp_rvalid && !u_meta_o_rd_empty;
assign u_result_i_wr_data = {u_meta_o_rd_data,i_tx_csr_rsp_rdata};
assign u_result_i_rd_en = pack_entry_done;
com_sync_fifo_ram_1p1bank #(
    .DW           (64              ),
    .RAM_DEPTH    (RESULT_DEPTH    ),
    .OUT_DEPTH    (RESULT_OUT_DEPTH),
    .RAM_RD_DELAY (RAM_RD_DELAY    )
)u_com_sync_fifo_ram_1p1bank_result
(
    .clk           (clk                  ), //i
    .rst_n         (rst_n                ), //i
    .clear         (clear                ), //i
    .i_wr_en       (u_result_i_wr_en     ), //i
    .i_wr_data     (u_result_i_wr_data   ), //i
    .o_wr_full     (u_result_o_wr_full   ), //o
    .i_rd_en       (u_result_i_rd_en     ), //i
    .o_rd_data     (u_result_o_rd_data   ), //o
    .o_rd_empty    (u_result_o_rd_empty  ), //o
    .o_water_level (                     ), //o
    .o_ram_ce_n    (o_result_ram_ce_n    ), //o
    .o_ram_we_n    (o_result_ram_we_n    ), //o
    .o_ram_addr    (o_result_ram_addr    ), //o
    .o_ram_wr_data (o_result_ram_wr_data ), //o
    .i_ram_rd_data (i_result_ram_rd_data )  //i
);

//assert----------------------------------------------------------------------
`COM_PARAM_ASSERT( CSR_AW>=1 && CSR_AW<=32, "CSR_AW must be in range 1 to 32" )
`COM_PARAM_ASSERT( EBUS_AW>=8 && EBUS_AW<=64, "EBUS_AW must be in range 8 to 64" )
`COM_PARAM_ASSERT( EBUS_DW>=32 && EBUS_DW%32==0, "EBUS_DW must be 32-bit word aligned" )
`COM_PARAM_ASSERT( EBUS_LW>=20, "EBUS_LW must cover maximum package and result length" )
`COM_PARAM_ASSERT( RD_OSD>=1 && RD_OSD<=32, "RD_OSD must be in range 1 to 32" )
`COM_PARAM_ASSERT( RESULT_DEPTH>=4 && RESULT_DEPTH%2==0, "RESULT_DEPTH must be even and at least 4" )
`COM_PARAM_ASSERT( RESULT_DEPTH>=RD_OSD, "RESULT_DEPTH must not be smaller than RD_OSD" )
`COM_PARAM_ASSERT( RAM_RD_DELAY>=1 && RAM_RD_DELAY<=16, "RAM_RD_DELAY must be in range 1 to 16" )
`COM_SIGNAL_ASSERT_LITE( a0, i_tx_csr_rsp_rvalid,!u_meta_o_rd_empty, "CSR response without metadata" )
`COM_SIGNAL_ASSERT_LITE( a1, u_result_i_wr_en,!u_result_o_wr_full, "CSR result FIFO overflow" )

endmodule
