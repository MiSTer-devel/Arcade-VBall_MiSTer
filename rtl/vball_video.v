
module vball_video(
  input reset,
  input clk,
  input flip,
  output reg hs,
  output reg vs,
  output reg hb,
  output reg vb,

  output nmi,
  output irq,

  output reg [8:0] hcount,
  output reg [8:0] vcount
);


assign nmi = vcount == 239 && hcount == 0;
assign irq = vcount[2:0] == 7 && hcount == 0;

// 0        240  320
// +---------+----+ 0
// |         |    |
// | screen  | hb |
// |         |    |
// +---------+----+ 239
// |    vblank    |
// +---------+----+ 273
//

// generate video signals
always @(posedge clk) begin
  if (reset) begin
  
    hcount <= 9'd0;
    vcount <= 9'd0;
  
  end
  else begin
  
    hcount <= hcount + 9'd1;
  
    case (hcount)
      1: hb <= 1'b0;
      241: hb <= 1'b1;
      289: hs <= 1'b0;
      321: hs <= 1'b1;
      400: begin
        vcount <= vcount + 9'd1;
        hcount <= 9'd0;
        case (vcount)
          0: vb <= 1'b0;
          240: vb <= 1'b1;
          243: vs <= 1'b0;
          253: vs <= 1'b1;
          259: vcount <= 9'b0;
        endcase
      end
    endcase
  
  end
    
end

endmodule