//--------------------------------------------------------------------------------
//Default parameters.
//--------------------------------------------------------------------------------
`ifndef COM_SYNC_STAGE
    `define COM_SYNC_STAGE 3
`endif

`ifndef COM_MEM_CTRL_W
    `define COM_MEM_CTRL_W 4
`endif

`ifndef COM_ECC_CTRL_W
    `define COM_ECC_CTRL_W 4
`endif

// Legacy width used by AXI/image/sim before their memory-control migration.
`ifndef COM_SRAM_W
    `define COM_SRAM_W `COM_MEM_CTRL_W
`endif

//--------------------------------------------------------------------------------
//FUNCTION DEFINE
//--------------------------------------------------------------------------------
//`define COM_MAX(a, b) ((a) > (b) ? (a) : (b))
//`define COM_MIN(a, b) ((a) < (b) ? (a) : (b))

//--------------------------------------------------------------------------------
//report&assert define
//--------------------------------------------------------------------------------
`define COM_PARAM_ASSERT( cond, estr )                               \
`ifdef COM_ASSERT_ON                                                 \
    initial begin                                                    \
        assert(cond) else $fatal("Com Parameter Error: '%s'",estr);  \
    end                                                              \
`endif

`define COM_SIGNAL_ASSERT( str_property, clk,rst_n, key,cond,estr )  \
`ifdef COM_ASSERT_ON                                                 \
    str_property: assert property (                                  \
        @(posedge clk) disable iff (!rst_n) key |-> (cond)           \
    ) else begin #100; $fatal("Com Signal Error: '%s'",estr); end    \
`endif

`define COM_SIGNAL_ASSERT_LITE( str_property, key,cond,estr )        \
`ifdef COM_ASSERT_ON                                                 \
    str_property: assert property (                                  \
        @(posedge clk) disable iff (!rst_n) key |-> (cond)           \
    ) else begin #100; $fatal("Com Signal Error: '%s'",estr); end    \
`endif
