
module vball(
  input reset,
  input clk_sys, // 48
  input clk_vid, // 24
  input clk, // en 2

  input [7:0] idata,
  input [24:0] iaddr,
  input iload,

  output [3:0] red,
  output [3:0] green,
  output [3:0] blue,
  output hs,
  output vs,
  output hb,
  output vb,

  output gfx_read,
  output [18:0] gfx_addr,
  input [7:0] gfx_data
);

wire [7:0] rom_data;
wire [7:0] ram_data, vram_data, attr_data;
wire [15:0] AB;
reg [7:0] DBi;
wire [7:0] DBo;
wire WE, irq, nmi;
reg nmi_latch, irq_latch;
wire [11:0] video_address;
wire [16:0] sra;
wire [7:0] video_vram_data, video_attr_data, srd1, srd2;
wire [7:0] col1_data, col2_data, col3_data;
wire [7:0] scol1_data, scol2_data, scol3_data;
reg [7:0] port_data;
wire [7:0] spr_data, smd, sma;

wire ram_en = AB[15:11] == 5'b00000; // 0-7ff
wire spr_en = AB[15:11] == 5'b00001; // 800-fff
wire port_en = AB[15:12] == 4'b0001; // 1000-1fff
wire vram_en = AB[15:12] == 4'b0010; // 2000-3fff
wire attr_en = AB[15:12] == 4'b0011; // 3000-3fff
wire bank_en = AB[15:14] == 4'b01; // 4000-7fff
wire rom_en = |AB[15:14]; // 4000-ffff

reg scrollx_hi, scrolly_hi;
reg [3:0] unknown_counter;
reg flip_screen;
reg [2:0] bg_bank;
reg [2:0] sp_bank;
reg main_bank;
reg tile_offset;
reg [7:0] bankswitch, scrollx_lo, scrolly_lo;
reg [7:0] irq_ack;
reg int_reset;
wire [8:0] hcount, vcount;


always @(posedge clk_sys) begin
  int_reset <= 1'b0;
  port_data <= 8'd0;
  if (port_en)
    case (AB[3:0])
      // 4'h0: // P1
      // 4'h1: // P2
      4'h2: port_data <= { 4'd0, vb, 1'b0, 1'b1, 1'b1 }; // SYS
      // 4'h3: // DSW1
      // 4'h4: // DSW2
      // 4'h5: // P3
      // 4'h6: // P4
      4'h8: { sp_bank, bg_bank, scrollx_hi, flip_screen } <= DBo; // scrollx hi
      4'h9: { scrolly_hi, tile_offset, unknown_counter, main_bank } <= DBo[6:0];
      4'hb: begin irq_ack <= DBo; int_reset <= 1'b1; end // irq_ack
      4'hc: scrollx_lo <= DBo; // scrollx low
      // 4'hd: // sound latch
      4'he: scrolly_lo <= DBo; // scrolly low
    endcase
end

// wire [7:0] gfx_data;
// wire [18:0] gfx_addr;

// rom #(.addr_width(19), .data_width(8)) gfx(
//   .clk(clk_sys),
//   .ce(1'b0),
//   .addr(gfx_addr),
//   .q(gfx_data),
//   .idata(idata),
//   .iaddr(iaddr[18:0]),
//   .iload(iaddr < 25'h80000) // 0-7ffff 8x64k
// );

rom rom(
  .clk(clk_sys),
  .ce(~rom_en),
  .addr(bank_en ? { 1'b0, main_bank, AB[13:0] } : AB),
  .q(rom_data),
  .idata(idata),
  .iaddr(iaddr[15:0]),
  .iload(iaddr < 25'h90000) // 80000-8ffff 64k
);

rom #(.addr_width(17), .data_width(8)) spr1(
  .clk(clk_sys),
  .ce(1'b0),
  .addr(sra),
  .q(srd1),
  .idata(idata),
  .iaddr({ ~iaddr[16], iaddr[15:0] }),
  .iload(iaddr < 25'hb0000) // 90000-cffff 128k
);

rom #(.addr_width(17), .data_width(8)) spr2(
  .clk(clk_sys),
  .ce(1'b0),
  .addr(sra),
  .q(srd2),
  .idata(idata),
  .iaddr({ ~iaddr[16], iaddr[15:0] }),
  .iload(iaddr < 25'hd0000) // 90000-cffff 128k
);

rom #(.addr_width(10), .data_width(8)) col1(
  .clk(clk_sys),
  .ce(1'b0),
  .addr(bg_col_addr),
  .q(col1_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iaddr < 25'hd0400)
);

rom #(.addr_width(10), .data_width(8)) col2(
  .clk(clk_sys),
  .ce(1'b0),
  .addr(bg_col_addr),
  .q(col2_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iaddr < 25'hd0c00)
);

rom #(.addr_width(10), .data_width(8)) col3(
  .clk(clk_sys),
  .ce(1'b0),
  .addr(bg_col_addr),
  .q(col3_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iaddr < 25'hd1400)
);

rom #(.addr_width(10), .data_width(8)) scol1(
  .clk(clk_sys),
  .ce(1'b0),
  .addr(sp_col_addr),
  .q(scol1_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iaddr < 25'hd0800)
);

rom #(.addr_width(10), .data_width(8)) scol2(
  .clk(clk_sys),
  .ce(1'b0),
  .addr(sp_col_addr),
  .q(scol2_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iaddr < 25'hd1000)
);

rom #(.addr_width(10), .data_width(8)) scol3(
  .clk(clk_sys),
  .ce(1'b0),
  .addr(sp_col_addr),
  .q(scol3_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iaddr < 25'hd1800)
);

dpram ram(
  .clk(clk_sys),
  .addr(AB[11:0]),
  .din(DBo),
  .q(ram_data),
  .rw(WE),
  .ce(~ram_en)
);

dpram spr_ram(
  .clk(clk_sys),
  .addr(AB[7:0]),
  .din(DBo),
  .q(spr_data),
  .rw(WE),
  .ce(~spr_en),
  .vaddr(sma),
  .vdata(smd)
);

dpram vram(
  .clk(clk_sys),
  .addr(AB[11:0]),
  .din(DBo),
  .q(vram_data),
  .rw(WE),
  .ce(~vram_en),
  .vaddr(video_address),
  .vdata(video_vram_data)
);

dpram attr(
  .clk(clk_sys),
  .addr(AB[11:0]),
  .din(DBo),
  .q(attr_data),
  .rw(WE),
  .ce(~attr_en),
  .vaddr(video_address),
  .vdata(video_attr_data)
);

always @(posedge clk)
  DBi <= rom_data | ram_data | vram_data | attr_data | port_data | spr_data;

cpu6502 cpu1(
  .clk(clk),
  .reset(reset),
  .AB(AB),
  .DI(DBi),
  .DO(DBo),
  .WE(WE),
  .IRQ(irq_latch),
  .NMI(nmi_latch),
  .RDY(1'b1)
);

vball_video vball_video(

  .clk(clk_vid),
  .flip(flip_screen),
  .hs(hs),
  .vs(vs),
  .hb(hb),
  .vb(vb),

  .nmi(nmi),
  .irq(irq),

  .hcount(hcount),
  .vcount(vcount)

);

wire active;
wire [3:0] bg_red, bg_green, bg_blue;
wire [3:0] sp_red, sp_green, sp_blue;
assign red = active ? sp_red : bg_red;
assign green = active ? sp_green : bg_green;
assign blue = active ? sp_blue : bg_blue;

wire [8:0] hcnt = hcount + 9'd12;
wire [8:0] vcnt = vcount + 9'd8;

vball_sprites vball_sprites(
  .clk_sys(clk_sys),
  .sp_bank(sp_bank),
  .sma(sma),
  .smd(smd),
  .sra(sra),
  .srd1(srd1),
  .srd2(srd2),
  .sca(sp_col_addr),
  .scd({ scol1_data[3:0], scol2_data[3:0], scol3_data[3:0] }),
  // .col_busy(col_busy),
  .hcount(hcnt),
  .vcount(vcnt),
  .red(sp_red),
  .green(sp_green),
  .blue(sp_blue),
  .active(active)
);

// wire col_busy;
wire [9:0] bg_col_addr;
wire [9:0] sp_col_addr;

// wire [10:0] col_addr = col_busy ? bg_col_addr : sp_col_addr;



vball_bg vball_bg(
  .clk_sys(clk_sys),

  .vaddr(video_address),
  .vram_data(video_vram_data),
  .attr_data(video_attr_data),

  .red(bg_red),
  .green(bg_green),
  .blue(bg_blue),

  .gfx_addr(gfx_addr),
  .gfx_data(gfx_data),
  .gfx_read(gfx_read),

  .col_addr(bg_col_addr),
  .col_data({ col1_data[3:0], col2_data[3:0], col3_data[3:0] }),
  // .col_busy(col_busy),

  .bg_bank(bg_bank),
  .tile_offset(tile_offset),
  .hcount(hcnt),
  .vcount(vcnt),

  .hscroll({ scrollx_hi, scrollx_lo }),
  .vscroll({ scrolly_hi, scrolly_lo }),
  .vb(vb)
);

always @(posedge clk) begin
  if (nmi) nmi_latch <= 1'b1;
  if (irq) irq_latch <= 1'b1;
  if (int_reset && irq_ack[0]) nmi_latch <= 1'b0;
  if (int_reset && irq_ack[1]) irq_latch <= 1'b0;
end

endmodule