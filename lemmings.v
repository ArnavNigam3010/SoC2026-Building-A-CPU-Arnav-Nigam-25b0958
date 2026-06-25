// ==========================================
// Lemmings 1: Walking
// States: 2
// L  -> Walk Left
// R  -> Walk Right
// ==========================================
module lemmings_1 (
    input clk,
    input areset,   
    input bump_left,
    input bump_right,
    output walk_left,
    output walk_right
); 

    reg state, next;
    localparam L = 1'b0, R = 1'b1;

    always @(*) begin
        case (state)
            L: next = bump_left  ? R : L;
            R: next = bump_right ? L : R;
        endcase
    end

    always @(posedge clk or posedge areset) begin
        if (areset) state <= L;
        else        state <= next;
    end

    assign walk_left  = (state == L);
    assign walk_right = (state == R);

endmodule


// ==========================================
// Lemmings 2: Falling
// States: 4
// L/R   -> Walking on ground
// FL/FR -> Falling through air
// ==========================================
module lemmings_2 (
    input clk,
    input areset, 
    input bump_left,
    input bump_right,
    input ground,
    output walk_left,
    output walk_right,
    output aaah
); 

    reg [1:0] state, next;
    localparam L = 2'd0, R = 2'd1, FL = 2'd2, FR = 2'd3;

    always @(*) begin
        case (state)
            L:  next = !ground ? FL : (bump_left  ? R  : L);
            R:  next = !ground ? FR : (bump_right ? L  : R);
            FL: next = ground  ? L  : FL;
            FR: next = ground  ? R  : FR;
        endcase
    end

    always @(posedge clk or posedge areset) begin
        if (areset) state <= L;
        else        state <= next;
    end

    assign walk_left  = (state == L);
    assign walk_right = (state == R);
    assign aaah       = (state == FL || state == FR);

endmodule


// ==========================================
// Lemmings 3: Digging
// States: 6
// DL/DR -> Digging states
// ==========================================
module lemmings_3 (
    input clk,
    input areset, 
    input bump_left,
    input bump_right,
    input ground,
    input dig,
    output walk_left,
    output walk_right,
    output aaah,
    output digging
); 

    reg [2:0] state, next;
    localparam L = 3'd0, R = 3'd1, FL = 3'd2, FR = 3'd3, DL = 3'd4, DR = 3'd5;

    always @(*) begin
        case (state)
            L:  next = !ground ? FL : (dig ? DL : (bump_left  ? R : L));
            R:  next = !ground ? FR : (dig ? DR : (bump_right ? L : R));
            FL: next = ground  ? L  : FL;
            FR: next = ground  ? R  : FR;
            DL: next = !ground ? FL : DL;
            DR: next = !ground ? FR : DR;
            default: next = L;
        endcase
    end

    always @(posedge clk or posedge areset) begin
        if (areset) state <= L;
        else        state <= next;
    end

    assign walk_left  = (state == L);
    assign walk_right = (state == R);
    assign aaah       = (state == FL || state == FR);
    assign digging    = (state == DL || state == DR);

endmodule


// ==========================================
// Lemmings 4: Splat
// States: 7
// DEAD -> Terminal state after 20+ cycles fall
// ==========================================
module lemmings_4 (
    input clk,
    input areset, 
    input bump_left,
    input bump_right,
    input ground,
    input dig,
    output walk_left,
    output walk_right,
    output aaah,
    output digging
);

    reg [2:0] state, next;
    reg [4:0] death_cnt;

    localparam L = 3'd0, R = 3'd1, FL = 3'd2, FR = 3'd3, DL = 3'd4, DR = 3'd5, DEAD = 3'd6;

    always @(posedge clk or posedge areset) begin
        if (areset) begin
            death_cnt <= 0;
        end else if (next == FL || next == FR) begin
            if (death_cnt < 5'd22) 
                death_cnt <= death_cnt + 1;
        end else begin
            death_cnt <= 0;
        end
    end

    always @(*) begin
        case (state)
            L:    next = !ground ? FL : (dig ? DL : (bump_left  ? R : L));
            R:    next = !ground ? FR : (dig ? DR : (bump_right ? L : R));
            FL:   next = ground  ? ((death_cnt > 5'd20) ? DEAD : L) : FL;
            FR:   next = ground  ? ((death_cnt > 5'd20) ? DEAD : R) : FR;
            DL:   next = !ground ? FL : DL;
            DR:   next = !ground ? FR : DR;
            DEAD: next = DEAD; 
            default: next = L;
        endcase
    end

    always @(posedge clk or posedge areset) begin
        if (areset) state <= L;
        else        state <= next;
    end

    assign walk_left  = (state == L);
    assign walk_right = (state == R);
    assign aaah       = (state == FL || state == FR);
    assign digging    = (state == DL || state == DR);

endmodule
