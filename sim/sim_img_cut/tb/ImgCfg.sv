class ImgCfg;
    //file I/O
    string case_dir;
    //config vars
    int pic_width;
    int pic_heigh;
    int pixel_bitlen;
    int pic_base_addr;
    int line_stride;
    int img_cut_wr_xpos;
    int img_cut_wr_ypos;
    int img_cut_wr_width;
    int img_cut_wr_heigh;
    int img_cut_rd_xpos;
    int img_cut_rd_ypos;
    int img_cut_rd_width;
    int img_cut_rd_heigh;
    //vars
    string dict_cfg[string];

extern function parse_cfgfile( string fn );
extern function int str2int( string s1 );
extern function build();

endclass:ImgCfg //--------------------------------------------

function int ImgCfg::str2int( string s1 );
    int a;
    integer ret;
    if( s1.substr(0,1)=="0x" )
        ret = $sscanf( s1.substr( 2, s1.len()-1 ), "%h", a );
    else
        ret = $sscanf( s1, "%d", a );

    // str2int = a;
    return a;
endfunction:str2int
function ImgCfg::parse_cfgfile( string fn );
    integer fp;
    string line;
    int ret;

    fp = $fopen(fn,"rt");
    if( fp==0 )begin
        $display("NOTICE(), no such file or dictionary: %s\n",fn);
        $stop;
    end

    while( !$feof(fp) ) begin
        string s1,s2;
        ret = $fgets(line,fp);
        if( line.len()>1 )begin
            if( line[ line.len()-1 ]=="\n" )
                line = line.substr(0, line.len()-2 );//delete \n
            if( line[0]=="#" ) continue;

            ret = $sscanf(line,"%s:%s",s1,s2);
            dict_cfg[s1] = s2;
            $display("key:%-20s, value:%-20s",s1,s2);
        end
    end
    $fclose(fp);

    //assign to config
    case_dir = dict_cfg["CaseDir"];
    pic_width        = str2int( dict_cfg["pic_width"] );
    pic_heigh        = str2int( dict_cfg["pic_heigh"] );
    pixel_bitlen     = str2int( dict_cfg["pixel_bitlen" ] );
    pic_base_addr    = str2int( dict_cfg["pic_base_addr"] );
    img_cut_rd_xpos  = str2int( dict_cfg["cut_rd_xpos" ] );
    img_cut_rd_ypos  = str2int( dict_cfg["cut_rd_ypos" ] );
    img_cut_rd_width = str2int( dict_cfg["cut_rd_width"] );
    img_cut_rd_heigh = str2int( dict_cfg["cut_rd_heigh"] );
    //display config
    line_stride = (pic_width*pixel_bitlen+127)/128*16;
    img_cut_wr_xpos = 0;
    img_cut_wr_ypos = 0;
    img_cut_wr_width = pic_width;
    img_cut_wr_heigh = pic_heigh;
    $display("\n\nparse config file done-----------------------");
    $display("pic_width    : %1d",pic_width);
    $display("pic_heigh    : %1d",pic_heigh);
    $display("pic_base_addr: 0x%1h",pic_base_addr);
    $display("line_stride  : 0x%1h",line_stride);
endfunction:parse_cfgfile

