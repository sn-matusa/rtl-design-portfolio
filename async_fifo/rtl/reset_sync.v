/***************************************************************************
*
* Module:       reset_sync
* Author:       Sebastian Matusa
* Created:      Oct 2025
*
* Description:
*   Two-flip-flop synchronizer for reset signal deassertion.
*   Ensures a clean, metastability-safe release of an asynchronous
*   reset within a specific clock domain.
*
* Revision History:
*   Rev 1.0 - Initial version (Sebastian Matusa, Oct 2025)
*
****************************************************************************/

module reset_sync (
    input  clk,             // Target clock domain
    input  rst_n_in,        // Asynchronous global reset (active-low)
    output reg rst_n_out    // Synchronized reset (active-low)
);

    // ---------------------------------------------------------
    // Two-stage synchronizer for asynchronous reset
    // ---------------------------------------------------------
    reg sync_ff;  // Intermediate stage

    always @(posedge clk or negedge rst_n_in) begin
        if (!rst_n_in)
            {rst_n_out, sync_ff} <= 2'b00;    // Reset both stages
        else
            {rst_n_out, sync_ff} <= {sync_ff, 1'b1}; // Shift '1' through
    end

endmodule
