class DmaDrv;

localparam AW = DmaPkg::BUS_AW;
localparam DW = DmaPkg::BUS_DW;
localparam LW = DmaPkg::BUS_LW;
localparam SW = DW/8;
typedef struct{
    int  addr;
    int  bytelen;
    // int  id;
} StuCmd;
typedef struct{
    bit [DW-1:0] data;
    // bit [SW-1:0] strb;
} StuDat;
typedef struct{
    int addr;
    int data;
} StuReg;

vDmaIf m_dma_vif;
StuCmd m_wch_cmd_buf[$];
StuCmd m_rch_cmd_buf[$];
StuDat m_wch_dat_buf[$];
event m_evt_wd;
string m_fn_pat;

extern function new( input vDmaIf dma_vif );
extern function build();
extern task run();

extern function parse_pat_file( string fn, ref StuCmd stu_cmd[$] );
extern function dump_stim_data( string fn );

extern function int get_stu_dat( int addr, int bytelen, ref StuDat stu_dat[256] );
extern function gen_wch_pattern_one( int addr, int bytelen );
extern function gen_wch_pattern();
extern function gen_rch_pattern_one( int addr, int bytelen );
extern function gen_rch_pattern();
extern task dma_config();
extern task dma_stim_wa( StuCmd cmd );
extern task dma_stim_ra( StuCmd cmd );
extern task dma_stim_wd();
extern task dma_stim_wch();
extern task dma_stim_rch();

//host function--------------------------
extern task host_set_reg( int addr, int data );
extern task host_get_reg( int addr, ref int data );
extern task host_init_config();
extern function parse_cfgfile( string fn, ref StuReg rv_stu_reg[$] );

endclass //DmaDrv

function DmaDrv::new( input vDmaIf dma_vif );
    m_dma_vif = dma_vif;
endfunction:new
function DmaDrv::build();
endfunction:build


//host function begin--------------------------
function DmaDrv::parse_cfgfile( string fn, ref StuReg rv_stu_reg[$] );
    integer fp;
    int ret;
    int i=0;

    fp = $fopen(fn,"rt");
    if( fp==0 )begin
        $display("NOTICE(), no such file or dictionary: %s\n",fn);
        $stop;
    end

    while( !$feof(fp) )begin
        string line;
        string str_addr;
        string str_data;
        int addr, data;

        if( $fgets(line,fp)==0 || line[0]=="\n")begin
            continue;
        end

        ret = $sscanf(line,"%s %s",str_addr,str_data);
        if( str_addr=="" || str_addr.substr(0,1)=="//" )
            continue;
        // $display("tydbg: get addr:%s data:%s", str_addr,str_data );

        if( str_addr.substr(0,1)=="0x" )begin
            ret = $sscanf( str_addr.substr( 2, str_addr.len()-1 ), "%h", addr );
        end
        else begin
            ret = $sscanf( str_addr, "%d", addr );
        end
        if( str_data.substr(0,1)=="0x" )begin
            ret = $sscanf( str_data.substr( 2, str_data.len()-1 ), "%h", data );
        end
        else begin
            ret = $sscanf( str_data, "%d", data );
        end

        rv_stu_reg[i].addr = addr;
        rv_stu_reg[i].data = data;
        $display("tydbg: out addr:0x%h data:0x%h", addr,data );
        i++;
    end
    $fclose(fp);

endfunction:parse_cfgfile

task DmaDrv::host_set_reg( int addr, int data );
    bit [DW-1:0] bus_data;
    int unsigned bus_bytelen = SW;
    int unsigned ui_addr = addr;
    int unsigned addr_lsb;

    addr_lsb = ui_addr%bus_bytelen;
    bus_data = data;
    bus_data = bus_data<<(addr_lsb*8);

    m_dma_vif.cb.bus_wa_addr <= addr;
    m_dma_vif.cb.bus_wa_bytelen <= 4;
    m_dma_vif.cb.bus_wa_valid<= 1'b1;
    do
        @m_dma_vif.cb;
    while( m_dma_vif.cb.bus_wa_ready==1'b0 );
    m_dma_vif.cb.bus_wa_valid<= 1'b0;

    m_dma_vif.cb.bus_wd_data <= bus_data;
    m_dma_vif.cb.bus_wd_valid<= 1'b1;
    do
        @m_dma_vif.cb;
    while( m_dma_vif.cb.bus_wd_ready==1'b0 );
    m_dma_vif.cb.bus_wd_valid<= 1'b0;
endtask:host_set_reg
task DmaDrv::host_get_reg( int addr, ref int data );
    bit [DW-1:0] bus_data;
    int unsigned bus_bytelen = SW;
    int unsigned ui_addr = addr;
    int unsigned addr_lsb;

    addr_lsb = ui_addr%bus_bytelen;

    m_dma_vif.cb.bus_ra_addr <= addr;
    m_dma_vif.cb.bus_ra_bytelen <= 4;
    m_dma_vif.cb.bus_ra_valid<= 1'b1;
    do
        @m_dma_vif.cb;
    while( m_dma_vif.cb.bus_ra_ready==1'b0 );
    m_dma_vif.cb.bus_ra_valid<= 1'b0;

    m_dma_vif.cb.bus_rd_ready <= 1'b1;
    do
        @m_dma_vif.cb;
    while( m_dma_vif.cb.bus_rd_valid==1'b0 );
    bus_data = m_dma_vif.cb.bus_rd_data;

    bus_data = bus_data>>(addr_lsb*8);
    data = bus_data;
endtask:host_get_reg
task DmaDrv::host_init_config();
    StuReg vec_stu_reg[$];
    string fn = "../tc/1_init_cfg.txt";
    int reg_size;

    parse_cfgfile( fn, vec_stu_reg );
    reg_size = vec_stu_reg.size();
    for( int i=0; i<reg_size; i++ )begin
        host_set_reg( vec_stu_reg[i].addr, vec_stu_reg[i].data );
    end
endtask:host_init_config
//host function end  --------------------------

function DmaDrv::parse_pat_file( string fn, ref StuCmd stu_cmd[$] );
    integer fp;
    int ret;
    StuCmd stu_cmd_t;
    int i=0;

    fp = $fopen(fn,"rt");
    if( fp==0 )begin
        $display("NOTICE(), no such file or dictionary: %s\n",fn);
        $stop;
    end

    while( !$feof(fp) )begin
        string str_addr;
        string str_bytelen;
        int addr, bytelen;
        ret = $fscanf( fp, "addr:%s bytelen:%s", str_addr,str_bytelen );
        if( str_addr=="" )
            continue;
        // $display("tydbg: get addr:%s bytelen:%s", str_addr,str_bytelen );

        if( str_addr.substr(0,1)=="0x" )begin
            ret = $sscanf( str_addr.substr( 2, str_addr.len()-1 ), "%h", addr );
        end
        else begin
            ret = $sscanf( str_addr, "%d", addr );
        end
        if( str_bytelen.substr(0,1)=="0x" )begin
            ret = $sscanf( str_bytelen.substr( 2, str_bytelen.len()-1 ), "%h", bytelen );
        end
        else begin
            ret = $sscanf( str_bytelen, "%d", bytelen );
        end

        stu_cmd[i].addr = addr;
        stu_cmd[i].bytelen = bytelen;
        i++;
    end
    $fclose(fp);

    // for( int i=0; i<stu_cmd.size(); i++ )begin
    //     $display("tydbg: final addr:%x bytelen:%d", stu_cmd[i].addr,stu_cmd[i].bytelen );
    // end
endfunction:parse_pat_file
function DmaDrv::dump_stim_data( string fn );
    integer fp;
    int ret;

    fp = $fopen(fn,"wt");
    if( fp==0 )begin
        $display("NOTICE(), no such file or dictionary: %s\n",fn);
        $stop;
    end

    for( int i=0; i<m_wch_dat_buf.size(); i++ )begin
        $fdisplay( fp, "%h",m_wch_dat_buf[i].data );
    end
    $fclose(fp);
endfunction:dump_stim_data

function int DmaDrv::get_stu_dat( int addr, int bytelen, ref StuDat stu_dat[256] );
    int bus_bytelen = SW;
    int addr_e = addr+bytelen;
    int addr_alg_word_s = (addr                )/bus_bytelen;
    int addr_alg_word_e = (addr_e+bus_bytelen-1)/bus_bytelen;
    int addr_s_mod = addr%bus_bytelen;
    int addr_e_mod = addr_e%bus_bytelen;
    int word_n = (addr_alg_word_e-addr_alg_word_s);
    StuDat stu_dat_t;

    int strb_s = ~((1<<addr_s_mod)-1);
    int strb_e =  ((1<<addr_e_mod)-1);

    for( int i=0; i<word_n; i++ )begin
        bit [DW-1:0] data;
        bit [SW-1:0] strb;

        data = $random;
        strb = i==0 ? strb_s : i==word_n-1 ? strb_e : {SW{1'b1}};

        stu_dat_t.data = data;
        stu_dat[i].data = stu_dat_t.data;
        m_wch_dat_buf.push_back( stu_dat_t );
    end

    get_stu_dat = word_n;
endfunction:get_stu_dat
function DmaDrv::gen_wch_pattern_one( int addr, int bytelen );
    StuCmd tmp_cmd;
    StuDat arr_tmp_dat[256];
    int word_n;

    tmp_cmd.addr    = addr;
    tmp_cmd.bytelen = bytelen;
    m_wch_cmd_buf.push_back( tmp_cmd );
    word_n = get_stu_dat( tmp_cmd.addr,tmp_cmd.bytelen,arr_tmp_dat );
endfunction:gen_wch_pattern_one
function DmaDrv::gen_rch_pattern_one( int addr, int bytelen );
    StuCmd tmp_cmd;

    tmp_cmd.addr    = addr;
    tmp_cmd.bytelen = bytelen;
    m_rch_cmd_buf.push_back( tmp_cmd );
endfunction:gen_rch_pattern_one

function DmaDrv::gen_wch_pattern();
    StuCmd cmd_buf[$];
    parse_pat_file( m_fn_pat, cmd_buf );
    for( int i=0; i<cmd_buf.size(); i++ )begin
        gen_wch_pattern_one( cmd_buf[i].addr, cmd_buf[i].bytelen );
    end
endfunction:gen_wch_pattern
function DmaDrv::gen_rch_pattern();
    StuCmd cmd_buf[$];
    parse_pat_file( m_fn_pat, cmd_buf );
    for( int i=0; i<cmd_buf.size(); i++ )begin
        gen_rch_pattern_one( cmd_buf[i].addr, cmd_buf[i].bytelen );
    end
endfunction:gen_rch_pattern
task DmaDrv::dma_config();
    @(m_dma_vif.cb );
    m_dma_vif.cb.axi_burst_len  <= 8'd7;
endtask:dma_config
task DmaDrv::dma_stim_wa( StuCmd cmd );
    m_dma_vif.cb.bus_wa_addr    <= cmd.addr;
    m_dma_vif.cb.bus_wa_bytelen <= cmd.bytelen;
    m_dma_vif.cb.bus_wa_valid   <= 1'b1;
    do
        @m_dma_vif.cb;
    while( m_dma_vif.cb.bus_wa_ready==1'b0 );
    m_dma_vif.cb.bus_wa_valid   <= 1'b0;
endtask:dma_stim_wa
task DmaDrv::dma_stim_ra( StuCmd cmd );
    m_dma_vif.cb.bus_ra_addr    <= cmd.addr;
    m_dma_vif.cb.bus_ra_bytelen <= cmd.bytelen;
    m_dma_vif.cb.bus_ra_valid   <= 1'b1;
    do
        @m_dma_vif.cb;
    while( m_dma_vif.cb.bus_ra_ready==1'b0 );
    m_dma_vif.cb.bus_ra_valid   <= 1'b0;
endtask:dma_stim_ra
task DmaDrv::dma_stim_wd();
    StuDat stu_dat;
    int tol_word_len = m_wch_dat_buf.size();
    int min_dat_wait_cycle = 0;
    int max_dat_wait_cycle = 10;
    int dat_wait_cycle = 0;

    @m_evt_wd;
    for( int i=0; i<tol_word_len; i++ )begin
        stu_dat = m_wch_dat_buf.pop_front();
        m_dma_vif.cb.bus_wd_data <= stu_dat.data;
        m_dma_vif.cb.bus_wd_valid<= 1'b1;
        do
            @m_dma_vif.cb;
        while( m_dma_vif.cb.bus_wd_ready==1'b0 );
        m_dma_vif.cb.bus_wd_valid<= 1'b0;

        dat_wait_cycle = min_dat_wait_cycle + $urandom%max_dat_wait_cycle;
        repeat(dat_wait_cycle) @(m_dma_vif.cb );
    end
endtask:dma_stim_wd
task DmaDrv::dma_stim_wch();
    StuCmd stu_cmd;
    int cmd_n = m_wch_cmd_buf.size();

    fork
      //wa
      begin:wa
        for( int i=0; i<cmd_n; i++ )begin
            stu_cmd = m_wch_cmd_buf.pop_front();
            dma_stim_wa( stu_cmd );
        end
      end
      //wd
      dma_stim_wd();
      //start wd
      begin:wd
        repeat(100) @(m_dma_vif.cb );
        ->m_evt_wd;
      end
    join_none
endtask:dma_stim_wch
task DmaDrv::dma_stim_rch();
    StuCmd stu_cmd;
    int cmd_n = m_rch_cmd_buf.size();

    fork
      //ra
      begin:ra
        for( int i=0; i<cmd_n; i++ )begin
            stu_cmd = m_rch_cmd_buf.pop_front();
            dma_stim_ra( stu_cmd );
        end
      end:ra
      //rd
      begin:rd
        @m_dma_vif.cb;
        m_dma_vif.cb.bus_rd_ready <= 1'b1;
      end:rd
    join_none
endtask:dma_stim_rch

task DmaDrv::run();
    m_fn_pat = "../tc/dma_pattern.txt";

    top.reset();
    dma_config();

    // host_init_config();

    gen_wch_pattern();
    gen_rch_pattern();
    dump_stim_data( "./dma_stim_data.txt" );
    fork
       dma_stim_wch();
       dma_stim_rch();
    join_none

    #20000;
    ->top.all_done;
    #10ns;
    $finish;
endtask:run
