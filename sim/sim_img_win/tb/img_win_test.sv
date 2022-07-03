program automatic img_win_test( ImgWinIf img_win_if );

ImgWinEnv cImgWinEnv;
initial begin
    cImgWinEnv = new( img_win_if );
    cImgWinEnv.build();
    cImgWinEnv.run();
end

endprogram:img_win_test