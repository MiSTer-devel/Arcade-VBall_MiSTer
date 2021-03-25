
module vball_video(
  input clk,
  input clk_sys,
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

assign nmi = vcount == 240 && hcount > 330;
assign irq = vcount[2:0] == 7 && hcount > 330;

// 0        240  336
// +---------+----+ 0
// |         |    |
// | screen  | hb |
// |         |    |
// +---------+----+ 240
// |    vblank    |
// +---------+----+ 261
//

// generate video signals
always @(posedge clk) begin
  hcount <= hcount + 1'b1;
  case (hcount)
    0: hb <= 1'b0;
    240: begin hb <= 1'b1; hs <= 1'b0; end
    280: hs <= 1'b1;
    336: begin
      vcount <= vcount + 9'b1;
      hcount <= 9'b0;
      case (vcount)
        240: vb <= 1'b1;
        244: vs <= 1'b0;
        247: vs <= 1'b1;
        261: begin
          vcount <= 9'b0;
          vb <= 1'b0;
        end
      endcase
    end
  endcase
end

endmodule