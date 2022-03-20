interface UniCSRIf;
    parameter  AW = 16;
    parameter  DW = 32;
    localparam SW = DW/8;

    wire                   CSRValid          ;
    wire                   CSRReady          ;
    wire                   bCSRWrite         ;
    wire [AW-1:0]          CSRAddr           ;
    wire [DW-1:0]          CSRRdData         ;
    wire [DW-1:0]          CSRWrData         ;
    wire [SW-1:0]          CSRWrStrb         ;

    modport Master(
        input  CSRReady,CSRRdData,
        output CSRValid,bCSRWrite,CSRAddr,CSRWrData,CSRWrStrb
        );

    modport Slave(
        output CSRReady,CSRRdData,
        input  CSRValid,bCSRWrite,CSRAddr,CSRWrData,CSRWrStrb
        );

    modport Monitor(
        input CSRValid,CSRReady,bCSRWrite
        );
endinterface


//--------------------------------------------------------------
interface com_csr_if;
    parameter  AW = 16;
    parameter  DW = 32;
    localparam SW = DW/8;

    wire                 csr_write ;
    wire [AW-1:0]        csr_addr  ;
    wire [DW-1:0]        csr_wdata ;
    wire [DW/8-1:0]      csr_wstrb ;
    wire                 csr_valid ;
    wire                 csr_ready ;
    wire [DW-1:0]        csr_rdata ;

    wire                   CSRValid          ;
    wire                   CSRReady          ;
    wire                   bCSRWrite         ;
    wire [AW-1:0]          CSRAddr           ;
    wire [DW-1:0]          CSRRdData         ;
    wire [DW-1:0]          CSRWrData         ;
    wire [SW-1:0]          CSRWrStrb         ;

    modport master(
        input  csr_ready,csr_rdata,
        output csr_valid,csr_write,csr_addr,csr_wdata,csr_wstrb
        );

    modport slave(
        output csr_ready,csr_rdata,
        input  csr_valid,csr_write,csr_addr,csr_wdata,csr_wstrb
        );

    modport monitor(
        input csr_valid,csr_ready,csr_write
        );
endinterface