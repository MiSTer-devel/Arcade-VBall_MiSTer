
module vball_video(
  input reset,
  input clk,
  input flip,
  input [3:0] h_center,
	input [2:0] v_center,
  input ycmode,

  output reg hs,
  output reg vs,
  output reg hb,
  output reg vb,

  output nmi,
  output irq,

  output reg [8:0] hcount,
  output reg [8:0] vcount
);

wire [9:0] horz_center = 10'd297 - $signed(h_center) - (ycmode ? 2'd3 : 0); 
wire [9:0] vert_center = 10'd248 - $signed(v_center) + (ycmode ? 2'd1 : 0);

reg [9:0] HCNT_DISPLAY;
reg [9:0] VCNT_DISPLAY;

always @(posedge clk) begin
    HCNT_DISPLAY <= ycmode ? 10'd380 : 10'd383;
    VCNT_DISPLAY <= ycmode ? 10'd260 : 10'd261;
end

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
      9'd1: hb <= 1'b0;
      9'd241: hb <= 1'b1;
      horz_center : hs <= 1'b0;
      (horz_center + 9'd32) : hs <= 1'b1;
      HCNT_DISPLAY: begin
        vcount <= vcount + 9'd1;
        hcount <= 9'd0;
        case (vcount)
          9'd239: vb <= 1'b1;
          vert_center : vs <= 1'b0;
          (vert_center + 9'd3) : vs <= 1'b1;
          VCNT_DISPLAY: begin
            vcount <= 9'b0;
            vb <= 9'd0;
          end
        endcase
      end
    endcase

  end

end

endmodule