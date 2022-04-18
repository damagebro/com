#var declare-------------------------------------------
MODULE="Img"
MODULE_LOWER="img_"
MODULE_UPPER="IMG_"

#script
#1.change tb/file content
sed -i s/Fifo/${MODULE}/g ./tb/FifoDrv.sv
sed -i s/Fifo/${MODULE}/g ./tb/FifoEnv.sv
sed -i s/Fifo/${MODULE}/g ./tb/FifoIf.sv
sed -i s/Fifo/${MODULE}/g ./tb/FifoPkg.sv
sed -i s/Fifo/${MODULE}/g ./tb/fifo_test.sv
sed -i s/Fifo/${MODULE}/g ./tb/top.sv

sed -i s/fifo_/${MODULE_LOWER}/g ./tb/FifoDrv.sv
sed -i s/fifo_/${MODULE_LOWER}/g ./tb/FifoEnv.sv
sed -i s/fifo_/${MODULE_LOWER}/g ./tb/FifoIf.sv
sed -i s/fifo_/${MODULE_LOWER}/g ./tb/FifoPkg.sv
sed -i s/fifo_/${MODULE_LOWER}/g ./tb/fifo_test.sv
sed -i s/fifo_/${MODULE_LOWER}/g ./tb/top.sv

sed -i s/FIFO_/${MODULE_UPPER}/g ./tb/FifoDrv.sv
sed -i s/FIFO_/${MODULE_UPPER}/g ./tb/FifoEnv.sv
sed -i s/FIFO_/${MODULE_UPPER}/g ./tb/FifoIf.sv
sed -i s/FIFO_/${MODULE_UPPER}/g ./tb/FifoPkg.sv
sed -i s/FIFO_/${MODULE_UPPER}/g ./tb/fifo_test.sv
sed -i s/FIFO_/${MODULE_UPPER}/g ./tb/top.sv

#2.renmae tb/file
mv ./tb/FifoDrv.sv    ./tb/${MODULE}Drv.sv  ;
mv ./tb/FifoEnv.sv    ./tb/${MODULE}Env.sv  ;
mv ./tb/FifoIf.sv     ./tb/${MODULE}If.sv   ;
mv ./tb/FifoPkg.sv    ./tb/${MODULE}Pkg.sv  ;
mv ./tb/fifo_test.sv  ./tb/${MODULE_LOWER}test.sv;