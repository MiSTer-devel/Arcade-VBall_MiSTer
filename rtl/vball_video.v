
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


assign nmi = vcount == 239 && hcount == 0;
assign irq = vcount[2:0] == 7 && hcount == 0;

// 0        255  335
// +---------+----+ 0
// |         |    |
// | screen  | hb |
// |         |    |
// +---------+----+ 239
// |    vblank    |
// +---------+----+ 260
//

// generate video signals
// Modeline '240x240@58,795' 4,83 240 252 276 310 240 243 246 265 -hsync -vsync nok
// modeline "240x240@57p;15,73989kHz" 5,036765 240 256 288 320 240 252 268 274 -hsync -vsync
always @(posedge clk) begin
  hcount <= hcount + 1'b1;
  case (hcount)
    0: hb <= 1'b0;
    240: hb <= 1'b1;
    256: hs <= 1'b0;
    288: hs <= 1'b1;
    320: begin
      vcount <= vcount + 9'b1;
      hcount <= 9'b0;
      case (vcount)
        239: vb <= 1'b1;
        251: vs <= 1'b0;
        267: vs <= 1'b1;
        273: begin
          vcount <= 9'b0;
          vb <= 1'b0;
        end
      endcase
    end
  endcase
end

endmodule