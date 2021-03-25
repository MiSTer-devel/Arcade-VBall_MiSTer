
module vball_sprites(
  input clk_sys,
  input [2:0] sp_bank,
  output reg [7:0] sma, // sprite mem addr
  input [7:0] smd, // sprite mem data
  output reg [16:0] sra, // sprite rom a
  input [7:0] srd1, // sprite rom data
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

// x___  ... 240 (00) spy
// /   \ ... scanline
// \___/ ... 225 (15) spyy (spy-h)
//


// r1[0], r1[4], r0[0], r0[4]
// r1[1], r1[5], r0[1], r0[5]
// r1[2], r1[6], r0[2], r0[6]
// r1[3], r1[7], r0[3], r0[7]

reg [3:0] state;
reg hbl;
reg [7:0] spy;
reg [7:0] spx;
wire [7:0] spyy = spy - (attr[7] ? 8'd32 : 8'd16);
reg [12:0] scanline1[275:0]; // active(1), colors(12)
reg [12:0] scanline2[275:0];
reg [3:0] scnx;

//reg [2:0] pxstate; // pxl machine state
reg [8:0] hcl, vcl;
reg [4:0] rsv; // relative sprite v (0-31)
//reg [3:0] rsh; // relative sprite h (0-15)
reg [7:0] attr, id;
reg [3:0] cid1, cid2;
// reg [11:0] color;

//wire [3:0] pxl1 = srd[3:0];// { srd[6], srd[4], srd[2], srd[0] };
//wire [3:0] pxl2 = srd[7:4];// { srd[7], srd[5], srd[3], srd[1] };

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
      // a = (j & 0x1ffc0) | (3-(j % 4)) * 16 + ((j % 64) >> 2)
      // rsv + (scnx/4) * 16 1bb40
      // sra <= { attr[2:0], id, 6'd0 } + { scnx[3:2], 4'd0 } + rsv;
      // sra <= { attr[2:0], (rsv > 9'd15 ? id+8'd1 : id), scnx[3:2], rsv[3:0] };
      // sra <= { attr[2:0], id, scnx[3:2], rsv[3:0] };
      sra <= { attr[2:0], (rsv > 9'd15 ? id+8'd1 : id) } * 64 + (3-(( attr[6] ? 15-scnx : scnx  )/4)) * 16 + rsv[3:0];
      state <= 4'd7;
    end
    4'd7: begin
      state <= 4'd8;
    end
    // 4'd8: begin
    //   //sca <= { sp_bank, attr[5:3], { cid, srd[scnx[1:0]], srd[scnx[1:0]+3'd4] } };
    //   //if (~col_busy) state <= 4'd9;
    //   state <= 4'd9;
    // end
    4'd8: begin
      if (attr[6]) begin
        case (scnx[1:0])
          2'b11: cid1 <= { srd2[7], srd2[3], srd1[7], srd1[3] };
          2'b10: cid1 <= { srd2[6], srd2[2], srd1[6], srd1[2] };
          2'b01: cid1 <= { srd2[5], srd2[1], srd1[5], srd1[1] };
          2'b00: cid1 <= { srd2[4], srd2[0], srd1[4], srd1[0] };
        endcase
      end
      else begin
        case (scnx[1:0])
          2'b00: cid1 <= { srd2[7], srd2[3], srd1[7], srd1[3] };
          2'b01: cid1 <= { srd2[6], srd2[2], srd1[6], srd1[2] };
          2'b10: cid1 <= { srd2[5], srd2[1], srd1[5], srd1[1] };
          2'b11: cid1 <= { srd2[4], srd2[0], srd1[4], srd1[0] };
        endcase
      end
      state <= 4'd9;
      // if (~col_busy) state <= 4'd9;
    end
    4'd9: begin
      sca <= { 1'b1, sp_bank, attr[5:3], cid1 };
      state <= 4'd10;
    end
    4'd10: begin
      // color <= scd;
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


/*
always @(posedge clk_sys) begin
  hbl <= hblank;
  hcl <= hcount;
  if (hblank) begin
    case (hbstate)
      3'd0: begin
        sma <= 8'd0;
        if (hbl^hblank) hbstate <= 3'd1;
      end
      3'd1: begin
        sma <= sma + 8'd1; // attribute addr
        spy <= 9'd240 - smd;
        hbstate <= 3'd2;
      end
      3'd2: begin
        sma <= sma + 8'd3; // default to next sprite
        hbstate <= sma >= 8'hfc ? 3'd0 : 3'd1; // default to done or skip
        if (spy <= vcount && spym > vcount) begin // if visible
          rsv <= vcount - spy - (attr[7] ? 9'd16 : 9'd0);
          attr <= smd;
          sma <= sma + 8'd1;
          hbstate <= 3'd3;
        end
      end
      3'd3: begin
        id <= smd;// + (rsv > 5'd15 ? 9'd1 : 9'd0);
        sma <= sma + 8'd1;
        scnx <= 4'd0;
        hbstate <= 3'd4;
      end
      3'd4: begin
        spx <= smd;
        sra <= { ~scnx[1], attr[2:0], id, scnx[3:1], rsv[2:0] };
        hbstate <= 3'd5;
      end
      3'd5: begin
        sca <= { sp_bank, attr[5:3], scnx[0] ? pxl2 : pxl1 };
        hbstate <= 3'd6;
      end
      3'd6: begin
        //scanline[spx+scnx] <= scd;
        scanline[spx+scnx] <= { 1'b1, 4'd0, attr[5:3], 5'd0 }; // dbg
        scnx <= scnx + 4'd1;
        hbstate <= scnx == 4'd15 ? sma >= 8'hfc ? 3'd0 : 3'd1 : 3'd4;
      end
    endcase
  end
  else begin
    { active, red, green, blue } <= scanline[hcount];
    if (hcl ^ hcount) scanline[hcl] <= 12'd0;
  end
end
*/

endmodule