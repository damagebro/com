#var declare-------------------------------------------
MODULE="Dma"
MODULE_LOWER="dma_"
MODULE_UPPER="DMA_"

#script
#1.change tb/file content
sed -i s/Img/${MODULE}/g ./tb/ImgDrv.sv
sed -i s/Img/${MODULE}/g ./tb/ImgEnv.sv
sed -i s/Img/${MODULE}/g ./tb/ImgIf.sv
sed -i s/Img/${MODULE}/g ./tb/ImgPkg.sv
sed -i s/Img/${MODULE}/g ./tb/img_test.sv
sed -i s/Img/${MODULE}/g ./tb/top.sv

sed -i s/img_/${MODULE_LOWER}/g ./tb/ImgDrv.sv
sed -i s/img_/${MODULE_LOWER}/g ./tb/ImgEnv.sv
sed -i s/img_/${MODULE_LOWER}/g ./tb/ImgIf.sv
sed -i s/img_/${MODULE_LOWER}/g ./tb/ImgPkg.sv
sed -i s/img_/${MODULE_LOWER}/g ./tb/img_test.sv
sed -i s/img_/${MODULE_LOWER}/g ./tb/top.sv

sed -i s/IMG_/${MODULE_UPPER}/g ./tb/DmaDrv.sv
sed -i s/IMG_/${MODULE_UPPER}/g ./tb/DmaEnv.sv
sed -i s/IMG_/${MODULE_UPPER}/g ./tb/DmaIf.sv
sed -i s/IMG_/${MODULE_UPPER}/g ./tb/DmaPkg.sv
sed -i s/IMG_/${MODULE_UPPER}/g ./tb/img_test.sv
sed -i s/IMG_/${MODULE_UPPER}/g ./tb/top.sv

#2.renmae tb/file
mv ./tb/ImgDrv.sv    ./tb/${MODULE}Drv.sv  ;
mv ./tb/ImgEnv.sv    ./tb/${MODULE}Env.sv  ;
mv ./tb/ImgIf.sv     ./tb/${MODULE}If.sv   ;
mv ./tb/ImgPkg.sv    ./tb/${MODULE}Pkg.sv  ;
mv ./tb/img_test.sv  ./tb/${MODULE_LOWER}test.sv;