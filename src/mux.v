module mux (
  input clk,
  input sel,
  input one,
  input two,
  output reg result
);
  always @ (posedge clk)
    if (sel)
      result <= one;
    else
      result <= two;
endmodule;