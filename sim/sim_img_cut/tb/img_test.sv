program automatic img_test( ImgIf img_if );

ImgEnv cImgEnv;
initial begin
    cImgEnv = new( img_if );
    cImgEnv.build();
    cImgEnv.run();
end

endprogram:img_test