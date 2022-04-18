program emi_test();

EmiEnv cEmiEnv;

initial begin
     cEmiEnv = new( top.emi_resp_if );
     cEmiEnv.build();
     cEmiEnv.run();
end

initial begin
    #10;
    $display("program yep!");
end
endprogram