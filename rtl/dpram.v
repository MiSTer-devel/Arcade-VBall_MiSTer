
module dpram
#(
  parameter addr_width=12,
  parameter data_width=8
)
(
  input clk,
  input [addr_width-1:0] addr,
  input [data_width-1:0] din,
  output [data_width-1:0] q,
  input rw,
  input ce,
  input [addr_width-1:0] vaddr,
  output reg [data_width-1:0] vdata
);

reg [data_width-1:0] data;
reg [data_width-1:0] mem[(1<<addr_width)-1:0];

assign q = ~ce ? data : 0;

always @(posedge clk) begin
  data <= mem[addr];
  if (~ce & rw) mem[addr] <= din;
end

always @(posedge clk)
  vdata <= mem[vaddr];

endmodule