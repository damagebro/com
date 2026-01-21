//1. enviroment various, (1)COM_PATH: common rtl library; (2)IMPL_PATH: implement relevant, memory+stdcell+dw+..; (3) RTL_PATH: project rtl path;
//2. recomment not use impl_template directly;  copy impl_template/ to your project, it can be modify;
//3. COM_PATH have 4 parts = "common"+"csr"(control&status register)+"axi"(external memroy interface, normally ddr access)+"img", it can be used separately;

//--------------------------------------
//define
//--------------------------------------
// $COM_PATH/com_define.sv
// $IMPL_PATH/define/impl_define_sim.sv

//--------------------------------------
//impl
//--------------------------------------
// -f $IMPL_PATH/impl.f

//--------------------------------------
//com
//--------------------------------------
-f $COM_PATH/filelist/com_common.f
-f $COM_PATH/filelist/com_axi.f
// -f $COM_PATH/filelist/com_csr.f
// -f $COM_PATH/filelist/com_img.f

//--------------------------------------
//project
//--------------------------------------
//-f $RTL_PATH/ip_diy.f