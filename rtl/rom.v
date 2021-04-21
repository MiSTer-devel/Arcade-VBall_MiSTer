
module rom
#(
  parameter addr_width=16,
  parameter data_width=8
)
(
  input clk,
  input ce_n,
  input [addr_width-1:0] addr,
  output [data_width-1:0] q,

  input [addr_width-1:0] iaddr,
  input [data_width-1:0] idata,
  input iload
);

reg [data_width-1:0] data;
reg [data_width-1:0] mem[(1<<addr_width)-1:0];

assign q = ~ce_n ? data : 0;

always @(posedge clk)
  data <= mem[addr];

always @(posedge clk)
  if (iload)
    mem[iaddr] <= idata;

endmodule