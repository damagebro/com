//1. enviroment various, (1)COM_PATH: common rtl library; (2)IMPL_PATH: implement relevant, memory+stdcell+dw+..; (3) RTL_PATH: project rtl path;
//2. recomment not use impl_template directly;  copy impl_template/ to your project, it can be modify;
//3. COM_PATH have 4 parts = "common"+"csr"(control&status register)+"emi"(external memroy interface, normally ddr access)+"img", it can be used separately;

//--------------------------------------
//define
//--------------------------------------
$COM_PATH/common/com_define.sv
$IMPL_PATH/impl_define_sim.sv

//--------------------------------------
//impl
//--------------------------------------
-f $IMPL_PATH/impl_template/com_impl.f

//--------------------------------------
//com
//--------------------------------------
-f $COM_PATH/common/com_common.f
//-f $COM_PATH/csr/com_csr.f
//-f $COM_PATH/emi/com_emi.f
//-f $COM_PATH/img/com_img.f

//--------------------------------------
//project
//--------------------------------------
//-f $RTL_PATH/ip_diy.f