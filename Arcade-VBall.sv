//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
// assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
// assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;

//assign VGA_SL = 0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;

assign AUDIO_S = 1;
// assign AUDIO_L = 0;
// assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_USER = 0;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////
// Status Bit Map: (0..31 => "O", 32..63 => "o")
// 0         1         2         3          4         5         6
// 01234567890123456789012345678901 23456789012345678901234567890123
// 0123456789ABCDEFGHIJKLMNOPQRSTUV 0123456789ABCDEFGHIJKLMNOPQRSTUV
//    XXX  XXXXXXXXX

wire [1:0] ar = status[9:8];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v"
localparam CONF_STR = {
	"VBall;;",
	"-;",
	"O89,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
 	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"-;",
	"P1,Screen Centering;",
	"P1OAD,H Center,0,+1,+2,+3,+4,+5,+6,+7,-8,-7,-6,-5,-4,-3,-2,-1;",
	"P1OEG,V Center,0,+1,+2,+3,-4,-3,-2,-1;",
	"-;",
	"DIP;",
	"-;",
	"T7,Service;",
	"T0,Reset;",
	"R0,Reset and close OSD;",
	"J1,Start1P,Start2P,A,B,CoinA,CoinB,Service;",
	"V,v",`BUILD_DATE
};

wire [21:0] gamma_bus;
wire forced_scandoubler;
wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

wire [15:0] joystick_0;
wire [15:0] joystick_1;
wire [15:0] joystick_2;
wire [15:0] joystick_3;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
	.gamma_bus(gamma_bus),

	.forced_scandoubler(forced_scandoubler),

	.buttons(buttons),
	.status(status),
	.status_menumask({status[5]}),

	.ps2_key(ps2_key),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wait(ioctl_wait),
	.ioctl_index(ioctl_index),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_2(joystick_2),
	.joystick_3(joystick_3)

);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys, locked, clk_vid, clk_48;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys), // 96
	.outclk_1(clk_48),
  	.outclk_2(clk_vid), // 6
	.locked(locked)
);

assign DDRAM_CLK = clk_48;

wire cen_main, cen_snd, cen_pcm, cen_vid;
clk_en #(18) clk_en_6502(clk_sys, cen_main);
clk_en #(4) clk_en_snd(clk_snd, cen_snd);
clk_en #(90) clk_en_pcm(clk_48, cen_pcm);
clk_en #(3) clk_en_vid(clk_48, cen_vid);

reg clk_snd;
reg [2:0] cnt;
always @(posedge clk_sys) begin
  cnt <= cnt + 3'd1;
  if (cnt == 3'd4) begin
    cnt <= 3'd0;
		clk_snd <= ~clk_snd;
  end
end

wire reset = RESET | status[0] | buttons[1] | ioctl_download;

//////////////////////////////////////////////////////////////////

reg [7:0] sw[8];
always @(posedge clk_sys)
	if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;

wire SERVICE = ~status[7];
wire [7:0] P1 = ~{
	joystick_0[4], // start1p
	joystick_0[5], // start1p
	joystick_0[7], // B
	joystick_0[6],	// A
	joystick_0[2], // down
	joystick_0[3], // up
	joystick_0[1], // left
	joystick_0[0], // right
};

wire [7:0] P2 = ~{
	joystick_1[4], // start2p
	joystick_1[5], // start1p
	joystick_1[7], // B
	joystick_1[6],	// A
	joystick_1[2], // down
	joystick_1[3], // up
	joystick_1[1], // left
	joystick_1[0], // right
};

wire [7:0] P3 = ~{
	joystick_2[4],// start3p
	joystick_2[5], // B
	joystick_2[7], // B
	joystick_2[6],	// A
	joystick_2[2], // down
	joystick_2[3], // up
	joystick_2[1], // left
	joystick_2[0], // right
};

wire [7:0] P4 = ~{
	joystick_0[4],// start4p
	joystick_3[5], // B
	joystick_3[7], // B
	joystick_3[6],	// A
	joystick_3[2], // down
	joystick_3[3], // up
	joystick_3[1], // left
	joystick_3[0], // right
};

wire COIN1 = ~joystick_0[8]; // R2?
wire COIN2 = ~joystick_0[9]; // ?

vball vball
(
	.reset(reset),
	.clk_sys(clk_sys),
	.clk_en(cen_main),
	.clk_snd(clk_snd),
	.cen_snd(cen_snd),
  	.cen_pcm(cen_pcm),
  	.clk_vid(clk_vid),

	.idata(ioctl_dout),
	.iaddr(ioctl_addr),
	.iload(ioctl_wr && ioctl_download && (ioctl_index==0)),

	.red(red),
	.green(green),
	.blue(blue),

	.hs(HSync),
	.vs(VSync),
	.hb(HBlank),
	.vb(VBlank),

	.h_center(status[13:10]),    //Screen centering
	.v_center(status[16:14]),

	.bg_addr(bg_addr),
	.bg_data(bg_data),
	.bg_read(bg_read),

	.pcm_rom_addr(pcm_rom_addr),
	.pcm_rom_data(pcm_rom_data),
	.pcm_rom_read(pcm_rom_read),
	.pcm_rom_data_rdy(pcm_rom_data_rdy),

	.audio_l(AUDIO_L),
	.audio_r(AUDIO_R),

	.P1(P1),
	.P2(P2),
	.P3(P3),
	.P4(P4),

	.COIN1(COIN1),
	.COIN2(COIN2),
	.SERVICE(SERVICE),

	.DSW1(sw[0]),
	.DSW2(sw[1])

);

reg ce_pix;
always @(posedge clk_48)
  if (cen_vid)  // 12
    ce_pix <= ~ce_pix;

arcade_video #(240,12) arcade_video
(
  .*,
  .clk_video(clk_48),
  .RGB_in({ red, green, blue }),
  .fx(status[5:3])
);

wire HBlank, VBlank;
wire HSync, VSync;
wire [3:0] red, green, blue;

wire [18:0] bg_addr;
wire [7:0] bg_data;
wire bg_read;

sdram sdram
(
	.*,
	.init(~locked),
	.clk(clk_sys),
	.addr(ioctl_download ? ioctl_addr : bg_addr),
	.wtbt(0),
	.dout(bg_data),
	.din(ioctl_dout),
	.rd(bg_read),
	.we(ioctl_index == 0 && ioctl_wr),
	.ready()
);

wire [63:0] ddram_data;
wire [17:0] pcm_rom_addr;
wire [7:0] pcm_rom_data = ddram_data[(pcm_rom_addr[2:0]*8)+:8];
wire pcm_rom_read;
wire pcm_rom_data_rdy;

ddram ddram
(
	.*,

	.ch1_addr(pcm_rom_addr),
	.ch1_dout(ddram_data),
	.ch1_din(64'b0),
	.ch1_rnw(1'b1),
	.ch1_req(pcm_rom_read),
	.ch1_ready(pcm_rom_data_rdy)
);

endmodule
