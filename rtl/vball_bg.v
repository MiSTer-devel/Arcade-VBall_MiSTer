
module vball_bg(
  input clk_sys,

  output [11:0] vaddr,
  input [7:0] vram_data,
  input [7:0] attr_data,

  output reg [3:0] red,
  output reg [3:0] green,
  output reg [3:0] blue,

  output reg [18:0] gfx_addr,
  input [7:0] gfx_data,
  output reg gfx_read,

  output reg [9:0] col_addr,
  input [11:0] col_data,

  input [2:0] bg_bank,
  input tile_offset,
  input [8:0] hcount,
  input [8:0] vcount,
  input [8:0] hscroll,
  input [8:0] vscroll,
  input vb

);

reg [8:0] hscr, vscr;
always @(posedge clk_sys)
  if (vb) begin
    hscr <= hscroll;
    vscr <= vscroll;
  end

wire [8:0] ph = hcount + hscr;
wire [8:0] pv = vcount + vscr;

wire [5:0] ty = pv[8:3];
wire [5:0] tx = ph[8:3];
wire [6:0] y1 = ty[5] ? 7'd32 : 0;
wire [6:0] y2 = tx[5] ? 7'd32 : 0;
assign vaddr = (ty+y1+y2)*32 + tx[4:0];

wire [3:0] pxl1 = { gfx_data[6], gfx_data[4], gfx_data[2], gfx_data[0] };
wire [3:0] pxl2 = { gfx_data[7], gfx_data[5], gfx_data[3], gfx_data[1] };

reg [8:0] hlatch;
reg [7:0] state;
always @(posedge clk_sys) begin
  hlatch <= hcount;
  case (state)
    8'd0: state <= hcount ^ hlatch ? 8'd1 : 8'd0;
    8'd1: begin
      gfx_addr <= { ~tile_offset, attr_data[4:0], vram_data, ph[2:1], pv[2:0] };
      gfx_read <= 1'b1;
      state <= 8'd2;
    end
    8'd2, 8'd3, 8'd4, 8'd5, 8'd6, 8'd7, 8'd8, 8'd9: state <= state + 8'd1;
    8'd10, 8'd11, 8'd12: begin
      col_addr <= { bg_bank, attr_data[7:5], ph[0] ? pxl2 : pxl1 };
      gfx_read <= 1'b0;
      state <= 8'd13;
    end
    8'd13: begin
      { red, green, blue } <= col_data;
      state <= 8'd0;
    end
  endcase
end

endmodule