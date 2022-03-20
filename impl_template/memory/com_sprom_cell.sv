//////////////////////////////////////////////////////////////////////////////
//
//  Description: ASIC Cells for sprom.
//
//  Authors:   wwq, ty
//  Version:   1.0
//
//////////////////////////////////////////////////////////////////////////////

module com_sprom_cell#(
    parameter DATA_W                   ,        // Data width of memory. No default value.
    parameter DEPTH                    ,        // Depth of memory. No default value.
    parameter ADDR_W    = $clog2(DEPTH),        // Address width, extra bits will be truncated.
    parameter MEM_USER  = 0            ,        // Memory user diy
    parameter MCFG_W    = `COM_DFT_W            // Default configuration width. Users can override it for special cases.
    )(
    input                       clk    ,
    input   logic [MCFG_W-1: 0] mem_cfg,

    input   logic [ADDR_W-1: 0] rd_addr,
    input   logic               rd_en  ,
    output  logic [DATA_W-1: 0] rd_data
    );

`ifndef COM_RAM_AS_BBOX
`ifdef COM_RAM_AS_REG
    localparam RAM_AS_REG = 1;
`else
    localparam RAM_AS_REG = 0;
`endif

//------------------------------------------------------------------------------
// Ram logic
//------------------------------------------------------------------------------
logic use_cell; // use cell as ram.

generate
    if(RAM_AS_REG) begin: USEREG
        com_sprom_sim#(
            .DATA_W (DATA_W ),
            .DEPTH  (DEPTH  ),
            .MEM_USER(MEM_USER),
            .ADDR_W (ADDR_W )
            )u_sprom_reg(
            .clk    (clk    ),
            .rd_en  (rd_en  ),
            .rd_addr(addr   ),
            .rd_data(rd_data)
            );
        assign use_cell = 1'b0;
    end
    else begin: USECELL
    /*************************************************************************************************/// Start of user logic.
        // if( DEPTH==1024 && DATA_W==128 && BE_W==1 && MEM_USER==0 )begin
        //     S2RAM1024X128_wrapper t_S2RAM1024X128_wrapper( .CK(clk), .DI(wr_data), .DOUT(rd_data), .RADR(rd_addr), .REN(~rd_en), .WADR(wr_addr), .WEN(~wr_en), .PD(mem_cfg[0]) );
        //     assign use_cell = 1'b1;
        // end
        if(0) begin
            assign use_cell = 1'b1;
        end
    /*************************************************************************************************/// End of user logic.
        else begin: NFOUND
            com_sprom_not_found#(
                .DATA_W (DATA_W ),
                .DEPTH  (DEPTH  ),
                .MEM_USER(MEM_USER),
                .ADDR_W (ADDR_W )
                )u_sprom_reg(
                .clk    (clk    ),
                .rd_en  (rd_en  ),
                .rd_addr(addr   ),
                .rd_data(rd_data)
                );
            assign use_cell = 1'b0;
        end
    end
endgenerate

//------------------------------------------------------------------------------
// Report & Assertion.
//------------------------------------------------------------------------------

//synopsys translate_off
`ifdef COM_REPORT_ON
    integer fp_mem;
    string s;
    string str_size;
    string str_user;
    string str_mem_type;
    initial begin
        str_mem_type = "sprom";
        fp_mem = $fopen({"./",str_mem_type,".lst"},"wt");
        $fclose(fp_mem);
    end
    initial begin
        #1;
        fp_mem = $fopen({"./",str_mem_type,".lst"},"at");
        str_user = "";
        if( MEM_USER!=0 )begin
            str_user = $psprintf("_usr%1d", MEM_USER);
        end
        str_size = $psprintf("%1dx",DEPTH);
        s = {str_mem_type,str_size,str_user};

        if(use_cell) begin                              // use cell
            $fwrite(fp_mem,"%-20s    Info: normal rom as cell;  %m\n",s);
        end
        else if(RAM_AS_REG) begin                      // use reg, in expection (forced by user)
            $fwrite(fp_mem,"%-20s Warning: set by user as dff(only for pre-sim!!!!!);  %m\n",s);
        end
        else begin                                      // use reg, out of expection
            $fwrite(fp_mem,"%-20s   Error: can't find wrapper;  %m\n",s);
        end
    end
`endif //end of COM_REPORT_ON

`ifdef COM_ASSERT_ON
    initial begin
        if(RAM_AS_REG) begin
            $warning("Stl Warning: Use reg as rom behavior model.");
        end
        else if(use_cell==1'b0) begin
            $fatal("Stl Error: Rom not found");
        end
    end
`endif
//synopsys translate_on

`endif //end of ifdef COM_RAM_AS_BBOX

endmodule


// Internal module for sim, only used for RAM_AS_REG
module com_sprom_sim #(
    parameter DEPTH    = 32,
    parameter DATA_W   = 20,
    parameter MEM_USER = 0,
    parameter ADDR_W   = $clog2(DEPTH>2? DEPTH : 2)
    )(
    input  wire                     clk     ,

    input  wire                     rd_en   ,
    input  wire [ADDR_W-1:0]        rd_addr ,
    output wire [DATA_W-1:0]        rd_data
    );

`ifdef COM_RAM_AS_REG
    //localparam-----------------------------------------------------------------
    //reg  declare---------------------------------------------------------------
    localparam USER = MEM_USER;

    reg  [ADDR_W-1:0] rc_addr;
    reg  [ DEPTH-1:0][DATA_W-1:0] arc_mem;
    //wire declare---------------------------------------------------------------
    //statement------------------------------------------------------------------
    initial begin
        integer fp;
        string fn;
        string rom_dir;
        string str_size;
        string str_user;
        string str_mem_type;

        rom_dir = "";
        str_size = $psprintf("%1dx%1d", DEPTH, DATA_W);
        str_user = USER==0 ? "" : $psprintf("_usr%1d", USER);
        str_mem_type = "sprom";
        fn = {str_mem_type, str_size, str_user, ".hex"};
        $readmemh(fn, arc_mem);
    end

    always @(posedge clk)
    begin
        if( rd_en )begin
            rc_addr <= rd_addr;
        end
    end
    assign rd_data = arc_mem[ rc_addr ];
`endif
endmodule
