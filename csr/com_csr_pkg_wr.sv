module com_csr_pkg_wr #(
    parameter CSR_AW  = 16,  //range=[8:32]
    parameter EBUS_AW = 64,  //range=[8:64]
    parameter EBUS_DW = 256, //range=[64::2^n]
    parameter EBUS_LW = 32,  //range=[20:EBUS_AW]
    parameter EBUS_UW = 1    //range=[1::]
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

    output wire                     o_tx_csr_req_write      ,
    output wire [CSR_AW-1:0]        o_tx_csr_req_addr       ,
    output wire [31:0]              o_tx_csr_req_wdata      ,
    output wire [3:0]               o_tx_csr_req_wstrb      ,
    output wire                     o_tx_csr_req_valid      ,
    input  wire                     i_tx_csr_req_ready      //,
);

//localparam-----------------------------------------------------------------
localparam EBUS_WN    = EBUS_DW/32;
localparam EBUS_WN_L2 = $clog2(EBUS_WN>1?EBUS_WN:2);

typedef enum logic [3:0] {
    eIDLE        = 4'd0,
    eRA          = 4'd1,
    eHEADER      = 4'd2,
    eHEADER_EXTD = 4'd3,
    eLW          = 4'd4,
    eBW_ADDR     = 4'd6,
    eBW_DATA     = 4'd7,
    eJUMP        = 4'd8,
    eERROR       = 4'd9
} state_t;

localparam [3:0] OP_LIST_WRITE  = 4'd0;
localparam [3:0] OP_BURST_WRITE = 4'd1;
localparam [3:0] OP_JUMP        = 4'd4;
localparam [3:0] OP_EXIT        = 4'd15;

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
reg  [1:0]                 r_beat_cnt;
reg  [EBUS_DW-1:0]         r_beat0_data;
reg  [EBUS_DW-1:0]         r_beat1_data;
reg  [EBUS_WN_L2-1:0]      r_beat_lane;

reg  [3:0]                 r_opcode;
reg  [3:0]                 r_extd_rem;
reg  [3:0]                 r_extd_idx;
reg  [15:0]                r_entry_rem;
reg  [31:0]                r_csr_addr;
reg  [63:0]                r_jump_addr;
reg  [31:0]                r_jump_bytesize;
reg                        r_jump_pending;
reg                        r_prefetch_req;
reg                        r_prefetch_sent;

reg  [EBUS_LW:0]           w_instr_words;
reg                        w_header_bad;
reg  [7:0]                 w_header_error_code;
wire [3:0]                 header_opcode;
wire [3:0]                 header_wordsize;
wire [15:0]                header_reg_num;
wire                       ebus_ra_hs;
wire                       ebus_rd_hs;
wire                       csr_req_hs;
wire                       word0_vld;
wire [31:0]                word0_data;
wire                       word1_vld;
wire [31:0]                word1_data;
wire [1:0]                 word_take_num;
wire                       beat_pop;
wire [EBUS_WN_L2-1:0]      load_lane;
wire [EBUS_WN_L2:0]        load_word_avl;
wire [EBUS_WN_L2:0]        ebus_word_take_num;
wire                       expected_rd_last;
wire                       beat_last_error;
wire                       start_align_error;
wire                       jump_align_error;
wire                       csr_addr_align_error;
wire                       header_error_event;
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
assign o_tx_ebus_rd_ready = (r_block_active && r_ebus_word_rem!='0 && (r_beat_cnt<2'd2 || beat_pop)) ||
                           (r_state==eERROR && r_prefetch_sent);

assign o_tx_csr_req_write = 1'b1;
assign o_tx_csr_req_addr = r_state==eLW ? word0_data[CSR_AW-1:0] : r_csr_addr[CSR_AW-1:0];
assign o_tx_csr_req_wdata = r_state==eLW ? word1_data : word0_data;
assign o_tx_csr_req_wstrb = 4'hf;
assign o_tx_csr_req_valid = ((r_state==eLW && word1_vld) || (r_state==eBW_DATA && word0_vld)) &&
                            !csr_addr_align_error;

//body---
assign ebus_ra_hs = o_tx_ebus_ra_valid && i_tx_ebus_ra_ready;
assign ebus_rd_hs = i_tx_ebus_rd_valid && o_tx_ebus_rd_ready && !r_prefetch_sent;
assign prefetch_ra_hs = ebus_ra_hs && r_prefetch_req;
assign prefetch_drain_hs = r_state==eERROR && r_prefetch_sent && i_tx_ebus_rd_valid && o_tx_ebus_rd_ready;
assign csr_req_hs = o_tx_csr_req_valid && i_tx_csr_req_ready;

assign word0_vld = r_beat_cnt!='0 && r_block_word_rem!='0;
assign word0_data = r_beat0_data[r_beat_lane*32 +: 32];
assign word1_vld = word0_vld && r_block_word_rem>EBUS_LW'('b1) &&
                   (r_beat_lane!=EBUS_WN_L2'(EBUS_WN-1) || r_beat_cnt==2'd2);
assign word1_data = r_beat_lane==EBUS_WN_L2'(EBUS_WN-1) ?
                    r_beat1_data[31:0] : r_beat0_data[(r_beat_lane+1'b1)*32 +: 32];
assign word_take_num = csr_req_hs && r_state==eLW ? 2'd2 :
                       (word0_vld && (r_state==eHEADER || r_state==eHEADER_EXTD || r_state==eBW_ADDR ||
                        r_state==eERROR) || (csr_req_hs && r_state==eBW_DATA)) ? 2'd1 : 2'd0;
assign beat_pop = word_take_num!='0 &&
                  ({1'b0,r_beat_lane}+word_take_num>=(EBUS_WN_L2+1)'(EBUS_WN) ||
                   r_block_word_rem<=word_take_num);

assign header_opcode = word0_data[31:28];
assign header_wordsize = word0_data[27:24];
assign header_reg_num = word0_data[15:0];

always @* begin
    w_instr_words = '0;
    w_header_bad = 1'b0;
    w_header_error_code = ERR_NONE;
    case( header_opcode )
        OP_LIST_WRITE: begin
            w_instr_words = (EBUS_LW+1)'(header_wordsize) +
                            (EBUS_LW+1)'({header_reg_num,1'b0});
            if( header_wordsize<4'd1 ) begin
                w_header_bad = 1'b1;
                w_header_error_code = ERR_BAD_HEADER;
            end
            else if( header_reg_num=='0 ) begin
                w_header_bad = 1'b1;
                w_header_error_code = ERR_BAD_REGNUM;
            end
        end
        OP_BURST_WRITE: begin
            w_instr_words = (EBUS_LW+1)'(header_wordsize) +
                            (EBUS_LW+1)'(header_reg_num) + 1'b1;
            if( header_wordsize<4'd1 ) begin
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
assign jump_align_error = r_jump_bytesize<32'd4 || |r_jump_bytesize[1:0] || |r_jump_addr[1:0] ||
                          |(r_jump_addr>>EBUS_AW) || |(r_jump_bytesize>>EBUS_LW);
assign csr_addr_align_error = word0_vld && ((r_state==eLW && word1_vld) || r_state==eBW_ADDR) &&
                              |word0_data[1:0];
assign header_error_event = r_state==eHEADER && word0_vld && w_header_bad;
assign done_event = word_take_num!='0 && ((r_state==eHEADER && header_opcode==OP_EXIT &&
                    header_wordsize==4'd1 && !w_header_bad) ||
                    (r_state==eHEADER_EXTD && r_extd_rem==4'd1 && r_opcode==OP_EXIT));
assign jump_limit_error = r_state==eJUMP && r_jump_cnt>{8'b0,r_jump_max_num_m1};
assign jump_register = r_state==eJUMP && !jump_align_error && !jump_limit_error;
assign jump_event = r_state==eHEADER && !r_block_active && r_jump_pending && r_prefetch_sent &&
                    !i_cfg_abort;
assign block_start = (ebus_ra_hs && !r_prefetch_req) || jump_event;
assign block_start_bytelen = jump_event ? EBUS_LW'(r_jump_bytesize) : r_block_bytesize;
assign block_end_error = r_state==eHEADER && !r_block_active && !r_jump_pending;
assign error_drain_done = !r_block_active && !r_prefetch_req && !r_prefetch_sent;

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
    else if( beat_last_error || csr_addr_align_error || block_end_error ) begin
        r_state <= eERROR;
    end
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
                else if( word0_vld ) begin
                    if( w_header_bad )
                        r_state <= eERROR;
                    else if( header_wordsize>4'd1 )
                        r_state <= eHEADER_EXTD;
                    else begin
                        case( header_opcode )
                            OP_LIST_WRITE:  r_state <= eLW;
                            OP_BURST_WRITE: r_state <= eBW_ADDR;
                            OP_EXIT: begin
                                r_state <= eIDLE;
                                r_busy <= 1'b0;
                            end
                            default: r_state <= eERROR;
                        endcase
                    end
                end
            end
            eHEADER_EXTD: begin
                if( word0_vld && r_extd_rem==4'd1 ) begin
                    case( r_opcode )
                        OP_LIST_WRITE:  r_state <= eLW;
                        OP_BURST_WRITE: r_state <= eBW_ADDR;
                        OP_JUMP:        r_state <= eJUMP;
                        OP_EXIT: begin
                            r_state <= eIDLE;
                            r_busy <= 1'b0;
                        end
                        default: r_state <= eERROR;
                    endcase
                end
            end
            eLW: begin
                if( csr_req_hs )
                    r_state <= r_entry_rem==16'd1 ? eHEADER : eLW;
            end
            eBW_ADDR: begin
                if( word0_vld )
                    r_state <= eBW_DATA;
            end
            eBW_DATA: begin
                if( csr_req_hs && r_entry_rem==16'd1 )
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
    else if( word_take_num!='0 ) begin
        r_block_word_rem <= r_block_word_rem - word_take_num;
        if( r_block_word_rem<=word_take_num )
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

//beat count
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_beat_cnt <= '0;
    else if( clear || block_start )
        r_beat_cnt <= '0;
    else begin
        case( {ebus_rd_hs,beat_pop} )
            2'b10: r_beat_cnt <= r_beat_cnt + 1'b1;
            2'b01: r_beat_cnt <= r_beat_cnt - 1'b1;
            default: r_beat_cnt <= r_beat_cnt;
        endcase
    end
end

//beat data FIFO
always @(posedge clk) begin
    if( ebus_rd_hs && beat_pop ) begin
        if( r_beat_cnt==2'd1 )
            r_beat0_data <= i_tx_ebus_rd_data;
        else begin
            r_beat0_data <= r_beat1_data;
            r_beat1_data <= i_tx_ebus_rd_data;
        end
    end
    else if( ebus_rd_hs ) begin
        if( r_beat_cnt=='0 )
            r_beat0_data <= i_tx_ebus_rd_data;
        else
            r_beat1_data <= i_tx_ebus_rd_data;
    end
    else if( beat_pop ) begin
        r_beat0_data <= r_beat1_data;
    end
end

//beat lane
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_beat_lane <= '0;
    else if( clear || block_start )
        r_beat_lane <= '0;
    else if( ebus_rd_hs && r_beat_cnt=='0 )
        r_beat_lane <= load_lane;
    else if( word_take_num!='0 ) begin
        if( r_block_word_rem<=word_take_num )
            r_beat_lane <= '0;
        else if( beat_pop )
            r_beat_lane <= EBUS_WN_L2'({1'b0,r_beat_lane}+word_take_num-(EBUS_WN_L2+1)'(EBUS_WN));
        else
            r_beat_lane <= EBUS_WN_L2'(r_beat_lane + word_take_num);
    end
end

//opcode
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_opcode <= '0;
    else if( clear )
        r_opcode <= '0;
    else if( r_state==eHEADER && word0_vld && !w_header_bad )
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
    else if( r_state==eHEADER && word0_vld && !w_header_bad ) begin
        r_extd_rem <= header_wordsize - 1'b1;
        r_extd_idx <= '0;
    end
    else if( r_state==eHEADER_EXTD && word0_vld ) begin
        r_extd_rem <= r_extd_rem - 1'b1;
        r_extd_idx <= r_extd_idx + 1'b1;
    end
end

//entry count
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_entry_rem <= '0;
    else if( clear )
        r_entry_rem <= '0;
    else if( r_state==eHEADER && word0_vld && !w_header_bad )
        r_entry_rem <= header_reg_num;
    else if( csr_req_hs )
        r_entry_rem <= r_entry_rem - 1'b1;
end

//CSR address
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_csr_addr <= '0;
    else if( clear )
        r_csr_addr <= '0;
    else if( r_state==eBW_ADDR && word0_vld )
        r_csr_addr <= word0_data;
    else if( r_state==eBW_DATA && csr_req_hs )
        r_csr_addr <= r_csr_addr + 32'd4;
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
    else if( r_state==eHEADER_EXTD && word0_vld && r_opcode==OP_JUMP ) begin
        if( r_extd_idx==4'd0 )
            r_jump_addr[31:0] <= word0_data;
        else if( r_extd_idx==4'd1 )
            r_jump_addr[63:32] <= word0_data;
        else if( r_extd_idx==4'd2 )
            r_jump_bytesize <= word0_data;
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
             !csr_addr_align_error && !beat_last_error )
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
    else if( r_state==eHEADER && word0_vld && !w_header_bad && header_opcode==OP_JUMP && r_jump_cnt=='0 )
        r_jump_max_num_m1 <= header_reg_num[7:0];
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
                       (r_busy && i_cfg_start) || (i_cfg_abort && r_busy) ||
                       beat_last_error || csr_addr_align_error || header_error_event || block_end_error ||
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
        else if( r_state==eJUMP && jump_align_error )
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
    else if( csr_req_hs && r_reg_done_cnt!='1 )
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

//assert----------------------------------------------------------------------
`COM_PARAM_ASSERT( CSR_AW>=8 && CSR_AW<=32, "CSR_AW must be in range 8 to 32" )
`COM_PARAM_ASSERT( EBUS_AW>=8 && EBUS_AW<=64, "EBUS_AW must be in range 8 to 64" )
`COM_PARAM_ASSERT( EBUS_DW>=64 && EBUS_DW%32==0 && (EBUS_DW&(EBUS_DW-1))==0,
                   "EBUS_DW must be a power of 2 and at least 64" )
`COM_PARAM_ASSERT( EBUS_LW>=20, "EBUS_LW must cover maximum package instruction length" )

endmodule
