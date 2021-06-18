
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


assign nmi = vcount == 240 && hcount == 0;
assign irq = vcount[2:0] == 7 && hcount == 0;

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
      287: hs <= 1'b0;
      319: hs <= 1'b1;
      399: begin
        vcount <= vcount + 9'd1;
        hcount <= 9'd0;
        case (vcount)
          239: vb <= 1'b1;
          248: vs <= 1'b0;
          251: vs <= 1'b1;
          258: begin
            vcount <= 9'b0;
            vb <= 9'd0;
          end
        endcase
      end
    endcase

  end

end

endmodule