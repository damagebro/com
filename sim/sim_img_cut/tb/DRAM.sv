class DRAM;

localparam  eMEM_DEPTH = 1<<25;
typedef struct{
    string fn;
    int  base_addr;
    int  byte_len;
    int  file_fmt_id; //0: txt, 1: bin
} StuList;

// import EmiPkg::*;
bit [7:0] mem[];
string m_case_dir;

extern function create();
extern function destroy();
extern function init( string case_dir );

function int get_str_bytelen( string str_line );
    get_str_bytelen = str_line.len()/2;
endfunction:get_str_bytelen
extern function str_msb2bytes_lsb( input  string str_line, int bytelen, ref bit[7:0] abuf[] );//in:str_line,bytelen;  out:pc_buf;
extern function bytes_lsb2str_msb( ref string str_line, input int bytelen,  bit[7:0] abuf[] );//in:pc_buf,bytelen;  out:str_line;
extern function int str2int( string s1 );
extern function int get_bin_file_len( string fn );

extern function load_bin_file(string fn, int base_addr);
extern function load_txt_file(string fn, int base_addr);
extern function dump_bin_file(string fn, int base_addr, int byte_len);
extern function dump_txt_file(string fn, int base_addr, int byte_len, int word_bytelen);
extern function split(string str, string delim_onechar, ref string rv_str[$]);
extern function parse_init_list( ref StuList rv_stu_init[$] );
extern function parse_dump_list( ref StuList rv_stu_dump[$] );

extern function deal_init_list();
extern function deal_dump_list();
extern function write_mem( int byte_addr, int byte_len, bit[7:0] pc_data[] );
extern function  read_mem( int byte_addr, int byte_len, ref bit[7:0] pc_data[] );

endclass:DRAM


function DRAM::create();
    mem = new [eMEM_DEPTH];
endfunction:create
function DRAM::destroy();
    deal_dump_list();
    mem.delete();
endfunction:destroy
function DRAM::init( string case_dir );
    m_case_dir = case_dir;
    deal_init_list();
endfunction:init

function DRAM::str_msb2bytes_lsb( input  string str_line, int bytelen, ref bit[7:0] abuf[] );//in:str_line,bytelen;  out:pc_buf;
    string str_sub;
    integer ret;
    for( int i=0; i<bytelen; i++ )begin
        str_sub = str_line.substr((bytelen-1-i)*2, (bytelen-1-i)*2+1);
        ret = $sscanf( str_sub, "%h", abuf[i] );
    end
endfunction:str_msb2bytes_lsb
function DRAM::bytes_lsb2str_msb( ref string str_line, input int bytelen,  bit[7:0] abuf[] );//in:pc_buf,bytelen;  out:str_line;
    string str_sub;
    str_line = "";
    for( int i=0; i<bytelen; i++ )begin
        $sformat( str_sub, "%02h", abuf[bytelen-1-i] );
        str_line = {str_line,str_sub};
    end
endfunction:bytes_lsb2str_msb
function int DRAM::str2int(string s1);
    int a;
    integer ret;
    if( s1.substr(0,1)=="0x" )
        ret = $sscanf( s1.substr( 2, s1.len()-1 ), "%h", a );
    else
        ret = $sscanf( s1, "%d", a );

    str2int = a;
endfunction:str2int
function int DRAM::get_bin_file_len(string fn);
    integer fp;
    int bytelen = 0;
    int ret;

    fp = $fopen(fn,"rb");
    if( fp==0 )begin
        $display("NOTICE(), no such file or dictionary: %s\n",fn);
        $stop;
    end

    ret = $fseek(fp,0,2);
    bytelen = $ftell(fp);
    $fclose(fp);

    get_bin_file_len = bytelen;
endfunction:get_bin_file_len
function DRAM::load_bin_file(string fn, int base_addr);
    integer fp;
    int bytelen = 0;
    int ret;

    fn = {m_case_dir,"/",fn};
    fp = $fopen(fn,"rb");
    if( fp==0 )begin
        $display("NOTICE(), no such file or dictionary: %s\n",fn);
        $stop;
    end

    bytelen = get_bin_file_len(fn);
    for( int i=0; i<bytelen; i++ )
        ret = $fread(mem[base_addr+i],fp);

    $fclose(fp);
endfunction:load_bin_file
function DRAM::load_txt_file(string fn, int base_addr);
    integer fp;
    string s1;
    bit[7:0] ac_buf[];
    int w=0;
    int word_bytelen;
    int ret;
    ac_buf = new[256];

    fn = {m_case_dir,"/",fn};
    fp = $fopen(fn,"rt");
    if( fp==0 )begin
        $display("NOTICE(), no such file or dictionary: %s\n",fn);
        $stop;
    end

    ret = $fgets(s1,fp);
    ret = $fseek(fp,0,0); //back start of file
    word_bytelen = get_str_bytelen(s1);
    while( !$feof(fp) )begin
        int dat;
        ret = $fgets(s1,fp);
        str_msb2bytes_lsb(s1, word_bytelen, ac_buf);
        write_mem(base_addr+w*word_bytelen,word_bytelen,ac_buf);
        w++;
    end

    $fclose(fp);
endfunction:load_txt_file
function DRAM::dump_bin_file(string fn, int base_addr, int byte_len);
    integer fp;

    fn = {m_case_dir,"/",fn};
    fp = $fopen(fn,"wb");
    if( fp==0 )begin
        $display("NOTICE(), no such file or dictionary: %s\n",fn);
        $stop;
    end

    for( int i=0; i<byte_len; i++ )begin
        $fwrite(fp,"%c",mem[base_addr+i]);
    end

    $fclose(fp);
endfunction:dump_bin_file
function DRAM::dump_txt_file(string fn, int base_addr, int byte_len, int word_bytelen);
    integer fp;
    bit[7:0] ac_buf_lsb[];
    string s1;
    ac_buf_lsb = new[256];

    fn = {m_case_dir,"/",fn};
    fp = $fopen(fn,"wt");
    if( fp==0 )begin
        $display("NOTICE(), no such file or dictionary: %s\n",fn);
        $stop;
    end

    for( int w=0; w<(byte_len+word_bytelen-1)/word_bytelen; w++ )begin
        read_mem( base_addr+w*word_bytelen, word_bytelen, ac_buf_lsb );
        bytes_lsb2str_msb(s1, word_bytelen, ac_buf_lsb);

        $fdisplay(fp,"%s",s1);
    end

    $fclose(fp);
endfunction:dump_txt_file
function DRAM::split(string str, string delim_onechar, ref string rv_str[$]);
    string str_pre, str_rem;  //"str_pre,delim_onechar*n,str_rem"
    int pre_epos, rem_spos;
    int delim_find_flag;
    int rem_len;

    assert( delim_onechar.len()==1 );
    if( delim_onechar.len()!=1 )begin
        $display("NOTICE(), delim must be single char, this delim is:'%s'\n",delim_onechar);
        $stop;
    end
    str_rem = str;
    rem_len = str_rem.len();
    while( rem_len>0 )begin
        delim_find_flag = 0;
        for( int i=0; i<rem_len; i++ )begin
            if(!delim_find_flag && str_rem[i]==delim_onechar[0] )begin
                pre_epos = i-1;
                delim_find_flag = 1;
            end
            rem_spos = i;
            if( delim_find_flag && str_rem[i]!=delim_onechar[0] )
                break;
        end//end for
        if( !delim_find_flag )begin
            pre_epos = rem_len-1;
        end

        if( pre_epos>0 )begin
            str_pre = str_rem.substr(0,pre_epos);
            rv_str.push_back( str_pre );
        end
        if( rem_spos<rem_len-1 )
            str_rem = str_rem.substr(rem_spos,rem_len-1);
        else
            str_rem = "";

        rem_len = str_rem.len();
    end//end while

endfunction:split
function DRAM::parse_init_list( ref StuList rv_stu_init[$] );
    integer fp;
    string fn = {m_case_dir,"/","dram_initial.lst"};
    StuList stu_init;
    string s1;
    string line;
    string ac;
    int ret;

    fp = $fopen(fn,"rt");
    if( fp==0 )begin
        $display("NOTICE(), no such file or dictionary: %s\n",fn);
        $stop;
    end

    while( !$feof(fp) )begin
        if( $fgets(line,fp)==0 || line[0]=="\n")begin
            continue;
        end

        if( line[ line.len()-1 ]=="\n" )begin
            line = line.substr(0, line.len()-2 );//delete \n
        end
        ret = $sscanf(line,"%s",ac);
        s1 = ac;

        if( s1=="FRM_TOTAL" || s1=="FRM_IDX" || s1=="FRM_END" )begin
            // printf("init list 0: %s, \n",ac);
        end
        else begin
            string vec_s[$];

            s1 = line;
            split(s1," ", vec_s);
            assert(vec_s.size()==2);
            if( vec_s.size()!=2 )begin
                $display("NOTICE(), the dram init/dump list illegel, this error line is:'%s'",s1);
                $stop;
            end

            stu_init.base_addr = str2int( vec_s[0] );
            stu_init.fn = vec_s[1];
            stu_init.file_fmt_id = 0;
            s1 = stu_init.fn;
            split(s1,".", vec_s);
            s1 = vec_s.pop_back();
            if( s1 == "bin" )
                stu_init.file_fmt_id = 1;
            rv_stu_init.push_back(stu_init);
            $display("init list 1: fn:%s, base_addr:0x%08x, stu_init.file_fmt_id:%1d",stu_init.fn,stu_init.base_addr,stu_init.file_fmt_id);
        end
    end//end of while(fp)

    $fclose(fp);
endfunction:parse_init_list
function DRAM::parse_dump_list( ref StuList rv_stu_dump[$] );
    integer fp;
    string fn = {m_case_dir,"/","dram_dump.lst"};
    StuList stu_dump;
    string s1;
    string line;
    string ac;
    int ret;

    fp = $fopen(fn,"rt");
    if( fp==0 )begin
        $display("NOTICE(), no such file or dictionary: %s\n",fn);
        $stop;
    end

    while( !$feof(fp) )begin
        if( $fgets(line,fp)==0 || line[0]=="\n")begin
            continue;
        end

        if( line[ line.len()-1 ]=="\n" )begin
            line = line.substr(0, line.len()-2 );//delete \n
        end
        ret = $sscanf(line,"%s",ac);
        s1 = ac;

        if( s1=="FRM_TOTAL" || s1=="FRM_IDX" || s1=="FRM_END" )begin
            // printf("init list 0: %s, \n",ac);
        end
        else begin
            string vec_s[$];

            s1 = line;
            split(s1," ", vec_s);
            assert(vec_s.size()==3);//{base_addr,len,fn}
            if( vec_s.size()!=3 )begin
                $display("NOTICE(), the dram init/dump list illegel, this error line is:'%s'",s1);
                $stop;
            end

            stu_dump.base_addr = str2int( vec_s[0] );
            stu_dump.byte_len = str2int( vec_s[1] );
            stu_dump.fn = vec_s[2];
            stu_dump.file_fmt_id = 0;
            s1 = stu_dump.fn;
            split(s1,".", vec_s);
            s1 = vec_s.pop_back();
            if( s1 == "bin" )
                stu_dump.file_fmt_id = 1;
            rv_stu_dump.push_back(stu_dump);
            $display("dump list 1: fn:%s, base_addr:0x%08x, byte_len:%08d, stu_dump.file_fmt_id:%1d",stu_dump.fn,stu_dump.base_addr,stu_dump.byte_len,stu_dump.file_fmt_id);
        end
    end//end of while(fp)

    $fclose(fp);
endfunction:parse_dump_list


function DRAM::deal_init_list();
    StuList vstu_init[$];
    parse_init_list(vstu_init);

    for( int i=0; i<vstu_init.size(); i++ )begin
        if( vstu_init[i].file_fmt_id==1 )
            load_bin_file(vstu_init[i].fn,vstu_init[i].base_addr);
        else
            load_txt_file(vstu_init[i].fn,vstu_init[i].base_addr);
    end
    if( vstu_init.size()==0 )begin //initial with fix data
        int a[4] = {32'h55,32'haa,32'h33,32'hcc};
        $display("NOTICE(), initial dram with fix data");
        // for( int i=0; i<eMEM_DEPTH/2; i++ )begin
        //     mem[i] = a[i[4:3]];
        // end
    end
endfunction:deal_init_list
function DRAM::deal_dump_list();
    StuList vstu_dump[$];
    int word_bytelen = 4;
    parse_dump_list(vstu_dump);

    for( int i=0; i<vstu_dump.size(); i++ )begin
        if( vstu_dump[i].file_fmt_id==1 )
            dump_bin_file(vstu_dump[i].fn,vstu_dump[i].base_addr,vstu_dump[i].byte_len);
        else
            dump_txt_file(vstu_dump[i].fn,vstu_dump[i].base_addr,vstu_dump[i].byte_len,word_bytelen);
    end
endfunction:deal_dump_list
function DRAM::write_mem( int byte_addr, int byte_len, bit[7:0] pc_data[] );
    for( int i=0; i<byte_len; i++ )begin
        mem[byte_addr+i] = pc_data[i];
    end
endfunction:write_mem
function DRAM::read_mem( int byte_addr, int byte_len, ref bit[7:0] pc_data[] );
    for( int i=0; i<byte_len; i++ )begin
        pc_data[i]= mem[byte_addr+i];
    end
endfunction:read_mem