
module vball(
  input reset,
  input clk_sys,
  input clk_en,
  input clk_snd,
  input cen_snd,
  input cen_pcm,

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

  output bg_read,
  output [18:0] bg_addr,
  input [7:0] bg_data,

  output [17:0] pcm_rom_addr,
  input [7:0] pcm_rom_data,
  output pcm_rom_read,
  input pcm_rom_data_rdy,

  output signed [15:0] audio_l,
  output signed [15:0] audio_r,

  input [7:0] P1,
  input [7:0] P2,
  input [7:0] P3,
  input [7:0] P4,

  input COIN1,
  input COIN2,
  input SERVICE,

  input [7:0] DSW1,
  input [7:0] DSW2

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
wire [9:0] bg_col_addr;
wire [9:0] sp_col_addr;

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


wire active;
wire [3:0] bg_red, bg_green, bg_blue;
wire [3:0] sp_red, sp_green, sp_blue;
assign red = active ? sp_red : bg_red;
assign green = active ? sp_green : bg_green;
assign blue = active ? sp_blue : bg_blue;

wire [8:0] hcnt = hcount + 9'd12;
wire [8:0] vcnt = vcount + 9'd8;


always @(posedge clk_sys) begin
  int_reset <= 1'b0;
  port_data <= 8'd0;
  if (port_en)
    case (AB[3:0])
      4'h0: port_data <= P1;
      4'h1: port_data <= P2;
      4'h2: port_data <= { 4'd0, vb, SERVICE, COIN2, COIN1 }; // SYS
      4'h3: port_data <= DSW1;
      4'h4: port_data <= DSW2;
      4'h5: port_data <= P3;
      4'h6: port_data <= P4;
      4'h8: if (WE) { sp_bank, bg_bank, scrollx_hi, flip_screen } <= DBo; // scrollx hi
      4'h9: if (WE) { scrolly_hi, tile_offset, unknown_counter, main_bank } <= DBo[6:0];
      4'hb: if (WE) begin irq_ack <= DBo; int_reset <= 1'b1; end // irq_ack
      4'hc: if (WE) scrollx_lo <= DBo; // scrollx low
      4'hd: if (WE) sound <= DBo;
      4'he: if (WE) scrolly_lo <= DBo; // scrolly low
    endcase
end

rom rom(
  .clk(clk_sys),
  .ce_n(~rom_en),
  .addr(bank_en ? { 1'b0, main_bank, AB[13:0] } : AB),
  .q(rom_data),
  .idata(idata),
  .iaddr(iaddr[15:0]),
  .iload(iload && iaddr < 25'h90000)
);

rom #(.addr_width(17), .data_width(8)) spr1(
  .clk(clk_sys),
  .ce_n(1'b0),
  .addr(sra),
  .q(srd1),
  .idata(idata),
  .iaddr({ ~iaddr[16], iaddr[15:0] }),
  .iload(iload && iaddr < 25'hb0000)
);

rom #(.addr_width(17), .data_width(8)) spr2(
  .clk(clk_sys),
  .ce_n(1'b0),
  .addr(sra),
  .q(srd2),
  .idata(idata),
  .iaddr({ ~iaddr[16], iaddr[15:0] }),
  .iload(iload && iaddr < 25'hd0000)
);

rom #(.addr_width(10), .data_width(8)) col1(
  .clk(clk_sys),
  .ce_n(1'b0),
  .addr(bg_col_addr),
  .q(col1_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iload && iaddr < 25'hd0400)
);

rom #(.addr_width(10), .data_width(8)) col2(
  .clk(clk_sys),
  .ce_n(1'b0),
  .addr(bg_col_addr),
  .q(col2_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iload && iaddr < 25'hd0c00)
);

rom #(.addr_width(10), .data_width(8)) col3(
  .clk(clk_sys),
  .ce_n(1'b0),
  .addr(bg_col_addr),
  .q(col3_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iload && iaddr < 25'hd1400)
);

rom #(.addr_width(10), .data_width(8)) scol1(
  .clk(clk_sys),
  .ce_n(1'b0),
  .addr(sp_col_addr),
  .q(scol1_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iload && iaddr < 25'hd0800)
);

rom #(.addr_width(10), .data_width(8)) scol2(
  .clk(clk_sys),
  .ce_n(1'b0),
  .addr(sp_col_addr),
  .q(scol2_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iload && iaddr < 25'hd1000)
);

rom #(.addr_width(10), .data_width(8)) scol3(
  .clk(clk_sys),
  .ce_n(1'b0),
  .addr(sp_col_addr),
  .q(scol3_data),
  .idata(idata),
  .iaddr(iaddr[9:0]),
  .iload(iload && iaddr < 25'hd1800)
);

dpram #(.addr_width(11), .data_width(8)) ram(
  .clk(clk_sys),
  .addr(AB[10:0]),
  .din(DBo),
  .q(ram_data),
  .rw(WE),
  .ce(~ram_en)
);

dpram #(.addr_width(8), .data_width(8)) spr_ram(
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

always @(posedge clk_en) // fix
  DBi <= rom_data | ram_data | vram_data | attr_data | port_data | spr_data;

cpu6502 cpu1(
  .clk(clk_en),
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

  .clk(clk_en),
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
  .hcount(hcnt),
  .vcount(vcnt),
  .red(sp_red),
  .green(sp_green),
  .blue(sp_blue),
  .active(active)
);

vball_bg vball_bg(
  .clk_sys(clk_sys),

  .vaddr(video_address),
  .vram_data(video_vram_data),
  .attr_data(video_attr_data),

  .red(bg_red),
  .green(bg_green),
  .blue(bg_blue),

  .gfx_addr(bg_addr),
  .gfx_data(bg_data),
  .gfx_read(bg_read),

  .col_addr(bg_col_addr),
  .col_data({ col1_data[3:0], col2_data[3:0], col3_data[3:0] }),

  .bg_bank(bg_bank),
  .tile_offset(tile_offset),
  .hcount(hcnt),
  .vcount(vcnt),

  .hscroll({ scrollx_hi, scrollx_lo }),
  .vscroll({ scrolly_hi, scrolly_lo }),
  .vb(vb)

);

always @(posedge clk_sys) begin
  if (clk_en) begin
    if (nmi) nmi_latch <= 1'b1;
    if (irq) irq_latch <= 1'b1;
    if (int_reset && irq_ack[0]) nmi_latch <= 1'b0;
    if (int_reset && irq_ack[1]) irq_latch <= 1'b0;
  end
end

/// AUDIO

wire [7:0] zrom_data, zram_data, zDO, ym_dout;
wire [15:0] zADDR;
wire zWE;
reg [7:0] sound, sound_latch;

wire zrom_en = zADDR[15] == 1'b0; // 0-7fff
wire zram_en = zADDR[15:11] == 5'b10000; // 8000-87ff
wire ym_en = zADDR[15:11] == 5'b10001; // 8800-8fff
wire oki_en = zADDR[15:11] == 5'b10011; // 9800-9fff
wire sndl_en = zADDR[15:13] == 3'b101; // a000-bfff

(*keep*)wire JT51IRQ;
wire zIORQ, zM1;
reg zNMI, zint_reset;
always @(posedge clk_snd) begin
  if (cen_snd) begin
    sound_latch <= sound;
    if (sound_latch ^ sound) begin
      zNMI <= 1'b1;
    end
    if (zint_reset) begin
      zNMI <= 1'b0;
    end
  end
end

always @(posedge clk_sys) begin
  zint_reset <= 1'b0;
  if (~zIORQ & ~zM1) zint_reset <= 1'b1;
end

wire [7:0] zDI =
  zrom_en ? zrom_data :
  zram_en ? zram_data :
  ym_en & zWE ? ym_dout :
  sndl_en ? sound :
  oki_en ? PCM_DO : 8'd0;

rom #(.addr_width(15), .data_width(8)) zrom(
  .clk(clk_sys),
  .ce_n(~zrom_en),
  .addr(zADDR),
  .q(zrom_data),
  .idata(idata),
  .iaddr(iaddr[14:0]),
  .iload(iload && iaddr < 25'he8000)
);

dpram #(.addr_width(11), .data_width(8)) zram(
  .clk(clk_sys),
  .addr(zADDR[10:0]),
  .din(zDO),
  .q(zram_data),
  .rw(~zWE),
  .ce(~zram_en)
);

jt51 jt51(
  .rst(reset),

  .clk(clk_snd),
  .cen_p1(cen_snd),

  .cs_n(~ym_en),
  .wr_n(zWE),
  .a0(zADDR[0]),
  .din(zDO),
  .dout(ym_dout),
  .irq_n(JT51IRQ),
  .xleft(ym_aud_l),
  .xright(ym_aud_r)
);


T80se T80se(
	.RESET_n(~reset),
	.CLK_n(clk_snd),
	.CLKEN(cen_snd),
	.WAIT_n(1'b1),
	.INT_n(JT51IRQ),
	.NMI_n(~zNMI),
	.BUSRQ_n(1'b1),
	.M1_n(zM1),
	.MREQ_n(),
	.IORQ_n(zIORQ),
	.RD_n(),
	.WR_n(zWE),
	.RFSH_n(),
	.HALT_n(),
	.BUSAK_n(),
	.A(zADDR),
	.DI(zDI),
	.DO(zDO)
);

wire signed [15:0] ym_aud_l;
wire signed [15:0] ym_aud_r;
wire signed [13:0] PCM_SOUND_OUT;
wire signed [16:0] MIX_L = { 1'b0, ym_aud_l } + { PCM_SND, 3'b0 };
wire signed [16:0] MIX_R = { 1'b0, ym_aud_r } + { PCM_SND, 3'b0 };

assign audio_l = MIX_L[15:0];
assign audio_r = MIX_R[15:0];

wire sample;
reg [17:0] pcm_old_addr;
reg pcm_data_rdy;
reg jt6295_wr;
reg [7:0] jt6295_din;

reg signed [13:0] PCM_SND;
always @(posedge clk_sys)
  if (sample) PCM_SND <= PCM_SOUND_OUT;

assign pcm_rom_read = pcm_old_addr[17:3] != pcm_rom_addr[17:3];


always @(posedge clk_sys) begin
  pcm_old_addr <= pcm_rom_addr;
  if (pcm_rom_data_rdy) pcm_data_rdy <= 1'b1;
  if (pcm_rom_addr !== pcm_old_addr) pcm_data_rdy <= 1'b0;
  if (oki_en & ~zWE) begin
    jt6295_wr <= 1'b0;
    jt6295_din <=  zDO;
  end
  if (cen_pcm) begin
    if (~jt6295_wr & zWE) jt6295_wr <= 1'b1;
  end
end

wire [7:0] PCM_DO;

jt6295 jt6295(
  .rst(reset),
  .clk(clk_sys),
  .cen(cen_pcm),
  .ss(1'b1),

  .wrn(jt6295_wr),
  .din(jt6295_din),
  .dout(PCM_DO),

  .rom_addr(pcm_rom_addr),
  .rom_data(pcm_rom_data),
  .rom_ok(pcm_data_rdy),

  .sound(PCM_SOUND_OUT),
  .sample(sample)
);

endmodule