
module clk_en #(
  parameter DIV=12
)
(
  input ref_clk,
  output reg cen
);

reg [15:0] cnt;
always @(posedge ref_clk) begin
  if (cnt == DIV) begin
    cnt <= 15'd0;
    cen <= 1'b1;
  end
  else begin
    cen <= 1'b0;
    cnt <= cnt + 15'd1;
  end
end

endmodule