
module vball_sprites(
  input clk_sys,
  input [2:0] sp_bank,
  output reg [7:0] sma,
  input [7:0] smd,
  output reg [16:0] sra,
  input [7:0] srd1,
  input [7:0] srd2,
  output reg [10:0] sca,
  input [11:0] scd,
  input col_busy,
  input [8:0] hcount,
  input [8:0] vcount,

  output reg [3:0] red,
  output reg [3:0] green,
  output reg [3:0] blue,
  output reg active
);

// sprite ram - 4 bytes x 64
// 0:y 1:attr 2:id 3:x
// attributes: 7     6      5:3    2:0
//             size  flipx  color  id[10:8]

reg [3:0] state;
reg hbl;
reg [7:0] spy;
reg [7:0] spx;
wire [7:0] spyy = spy - (attr[7] ? 8'd32 : 8'd16);
reg [12:0] scanline1[275:0];
reg [12:0] scanline2[275:0];
reg [3:0] scnx;
reg [8:0] hcl, vcl;
reg [4:0] rsv;
reg [7:0] attr, id;
reg [3:0] cid;

wire [7:0] vcntv = 8'd240 - vcount;

always @(posedge clk_sys) begin
  hcl <= hcount;
  vcl <= vcount;
  case (state)
    4'd0: begin
      sma <= 8'd2;
      if (vcl ^ vcount) state <= 4'd1;
    end
    4'd1: begin
      if (smd == 8'd0) begin
        state <= sma >= 8'hfc ? 4'd0 : 4'd1;
        sma <= sma + 8'd4;
      end
      else begin
        id <= smd;
        sma <= sma - 8'd2;
        state <= 4'd2;
      end
    end
    4'd2: begin
      state <= 4'd3;
      sma <= sma + 8'd1;
    end
    4'd3: begin
      spy <= smd;
      sma <= sma + 8'd2;
      state <= 4'd4;
    end
    4'd4: begin
      attr <= smd;
      sma <= sma + 8'd3;
      if (smd[7]) spy <= spy + 8'd16;
      scnx <= 4'd0;
      state <= 4'd5;
    end
    4'd5: begin
      spx <= smd;
      state <= sma == 8'hfe ? 3'd0 : 3'd1;
      rsv <= spy - vcntv;
      if (spy >= vcntv && spyy < vcntv) state <= 4'd6;
    end
    4'd6: begin
      sra <= { attr[2:0], (rsv > 9'd15 ? id+8'd1 : id) } * 64 + (3-(( attr[6] ? 15-scnx : scnx  )/4)) * 16 + rsv[3:0];
      state <= 4'd7;
    end
    4'd7: begin
      state <= 4'd8;
    end
    4'd8: begin
      if (attr[6]) begin
        case (scnx[1:0])
          2'b11: cid <= { srd2[7], srd2[3], srd1[7], srd1[3] };
          2'b10: cid <= { srd2[6], srd2[2], srd1[6], srd1[2] };
          2'b01: cid <= { srd2[5], srd2[1], srd1[5], srd1[1] };
          2'b00: cid <= { srd2[4], srd2[0], srd1[4], srd1[0] };
        endcase
      end
      else begin
        case (scnx[1:0])
          2'b00: cid <= { srd2[7], srd2[3], srd1[7], srd1[3] };
          2'b01: cid <= { srd2[6], srd2[2], srd1[6], srd1[2] };
          2'b10: cid <= { srd2[5], srd2[1], srd1[5], srd1[1] };
          2'b11: cid <= { srd2[4], srd2[0], srd1[4], srd1[0] };
        endcase
      end
      state <= 4'd9;
    end
    4'd9: begin
      sca <= { 1'b1, sp_bank, attr[5:3], cid };
      state <= 4'd10;
    end
    4'd10: begin
      state <= 4'd11;
    end
    4'd11: begin
      if (cid1 != 0) begin
        if (vcount[0]) begin
          scanline1[spx+scnx+6] <= { 1'b1, scd };
        end
        else begin
          scanline2[spx+scnx+6] <= { 1'b1, scd };
        end
      end
      scnx <= scnx + 4'd1;
      state <= scnx == 4'd15 ? sma == 8'hfe ? 4'd0 : 4'd1 : 4'd6;
    end
  endcase
  if (vcount[0]) begin
    { active, red, green, blue } <= scanline2[hcount];
    if (hcl ^ hcount) scanline2[hcl] <= 13'd0;
  end
  else begin
    { active, red, green, blue } <= scanline1[hcount];
    if (hcl ^ hcount) scanline1[hcl] <= 13'd0;
  end

end

endmodule