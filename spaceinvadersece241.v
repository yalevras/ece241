`timescale 1ns/1ns

module part1
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
		KEY, SW,
		// On Board Keys
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B,
		
	);
	
	input			CLOCK_50;				//	50 MHz
	input	[3:0]	KEY;
	input [5:0] SW;
	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[7:0]	VGA_R;   				//	VGA Red[7:0] Changed from 10 to 8-bit DAC
	output	[7:0]	VGA_G;	 				//	VGA Green[7:0]
	output	[7:0]	VGA_B;   				//	VGA Blue[7:0]
	
	wire resetn;
	assign resetn = SW[0];
	
	//FOR FALLING BLOCKS
	wire [2:0] in_colour;
	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire [2:0] x_inc, y_inc;
	wire go, erase, plot_to_vga, update;
	
	assign go = KEY[3];
	
	wire [25:0] freq, control_freq;
	wire [7:0] x_pos;
	wire [6:0] y_pos;
	wire [5:0] FrameCounter;
	wire [15:0] ClearCounter;
	
	//FOR BULLET
	assign shoot = KEY[0];

	wire [1:0] plot_bullet, erase_bullet;
	wire [1:0] bx_inc, by_inc;

	wire [7:0] bullet_posx;
	wire [6:0] bullet_posy;
	wire [3:0] bullet_finalc;

	wire [7:0] bullet_x;
	wire [6:0] bullet_y;
	wire [3:0] bullet_c; 

	wire hit;
	wire flying;
	wire [7:0] rocketX;
	wire [6:0] rocketY;
	wire [1:0] speed, rockethit;
	
	
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(plot_to_vga),
			
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
			
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "display.mif";
	
	
	//FOR FALLING BLOCKS
	
	Control c(CLOCK_50, resetn, FrameCounter, ClearCounter, x_pos, y_pos, in_colour, freq, control_freq, go, erase, update, plot_to_vga, x_inc, y_inc, KEY[2], KEY[1], KEY[0]);

	DataPath dp(CLOCK_50, resetn, plot_to_vga, erase, update, in_colour, x, y, colour, x_pos, y_pos, x_inc, y_inc);

endmodule


module Control (Clock, Reset_n, FrameCounter, ClearCounter, x_pos, y_pos, in_colour, freq, control_freq, go, erase, update, plot_to_vga, x_inc, y_inc, ld_left, ld_right, shoot);

	input Clock, Reset_n, go, ld_left, ld_right, shoot;
	
	output reg [25:0] freq, control_freq;
   output reg [5:0] FrameCounter;
	output reg [16:0] ClearCounter;
	
	output reg [7:0] x_pos;
	output reg [6:0] y_pos;
	output reg erase, update, plot_to_vga;
	output reg [2:0] x_inc, y_inc, in_colour;
	
	reg [4:0] current_state, next_state;
	reg [5:0] col_count, row_count;
	reg [7:0] x_temp, y_temp, y_temp2, bx_temp, by_temp;
	reg [7:0] g3, g3, g1, b3, b2, b1, r3, r2, r1, p3, p2, p1, y3, y2, y1;
	reg 1done, 2done, 3done, 4done, 5done, 6done, 7done, 8done, 9done, gamedone;
	reg [25:0] control_count;
	
	
	parameter X_SCREEN_PIXELS = 8'd160;
   parameter Y_SCREEN_PIXELS = 7'd120;
	parameter X_BOXSIZE = 8'd4;   // Box X dimension
   parameter Y_BOXSIZE = 7'd4;
	parameter X_MAX = X_SCREEN_PIXELS - 1 - X_BOXSIZE; // 0-based and account for box width
   parameter Y_MAX = Y_SCREEN_PIXELS - 1 - Y_BOXSIZE;
	
	localparam  
					S_START_SCREEN = 4'd0,
					S_CLEAR_SCREEN    = 4'd1,
					S_PREP_SCREEN = 4'd2,
	
               S_DISPLAY = 4'd3,
					S_UPDATE_COLUMN = 4'd4,
					S_UPDATE_ROW = 4'd5,
					
					S_PREP_CONTROLLER = 4'd6,
					S_DRAW_CONTROLLER = 4'd7,
					
					// ver 1
					/*
					S_CONTROLLER_WAIT = 4'd8,
					S_PRE_ERASE_C = 4'd9,
					S_CONTROLLER_ERASE = 4'd10,
               S_CONTROLLER    = 4'd11,
					
					S_PRE_UPDATE = 4'd12,
               S_ERASE   = 4'd13,
					S_UPDATE  = 4'd14,
					S_RESET   = 4'd15;
					*/
					
					// ver 2
					
					// draw bullet
					// temp variable for bullet
					S_PREP_BULLET = 4'd8,
					S_DRAW_BULLET = 4'd9,
			 
					S_UPDATE_BULLET = 4'd10,

					S_LOSING_MOVE = 4'd11,

					S_LOSE_SCREEN = 4'd12,

					S_WINNING_LOGIC = 4'd13,
			 
					S_WAIT_BULLET = 4'd11,
			 
					//S_PRE_ERASE_BULLET: next_state = S_ERASE_BULLET;
			 
					S_ERASE_BULLET = 4'd12,
					
					
					S_CONTROLLER_WAIT = 4'd13,
					S_PRE_ERASE_C = 4'd14,
					S_CONTROLLER_ERASE = 4'd15,
               S_CONTROLLER    = 4'd16,
					
					S_PRE_UPDATE = 4'd17,
               S_ERASE   = 4'd18,
					S_UPDATE  = 4'd19,
					S_RESET   = 4'd20;
					
    
    always@(posedge Clock)
    begin
		case (current_state)
		
			 //this is gonna be the opening screen, when KEY[3] is pressed we go to the next state
			 S_START_SCREEN: if (~go) 
									  next_state = S_CLEAR_SCREEN;
								  else 
									  next_state = S_START_SCREEN;
			//now we clear the screen, im gonna edit this so that only part of the screen gets cleared
			 S_CLEAR_SCREEN: next_state = (ClearCounter == 17'd25000) ? S_PREP_SCREEN : S_CLEAR_SCREEN;			 
			 //now prep the screen for display
			 S_PREP_SCREEN: next_state = S_DISPLAY;			 
			 //here we load the boxes that will fall from the sky
			 S_DISPLAY: next_state = (FrameCounter == 4'd15) ? S_UPDATE_COLUMN : S_DISPLAY;			 			 
			 //now lets move to the next COLUMN
			 S_UPDATE_COLUMN: next_state = (col_count < 4'd4) ? S_DISPLAY : (row_count == 0 || row_count == 1) ? S_UPDATE_ROW : (col_count == 4'd4 && control_count == 0) 
			 ? S_PREP_CONTROLLER : (col_count == 4'd4 && control_count == 1) ? S_DRAW_CONTROLLER : (col_count < 4'd10) ? S_ERASE : (row_count == 2'd2 || row_count == 2'd3) ? S_UPDATE_ROW : S_UPDATE;		 
			 //now lets move to the next row
			 S_UPDATE_ROW: next_state = (row_count == 0 || row_count == 1) ? S_DISPLAY : (row_count == 2'd2 || row_count == 2'd3) ? S_ERASE: S_UPDATE_COLUMN;			  
			 //now we prep the spaceship for plotting
			 S_PREP_CONTROLLER: next_state = S_DRAW_CONTROLLER;			 
			 //draw spaceship in between the wait cycle for the falling blocks
			 S_DRAW_CONTROLLER: next_state = (FrameCounter <= 6'd54) ? S_DRAW_CONTROLLER : S_PREP_BULLET;
			 S_PREP_BULLET: next_state = S_PRE_DRAW_BULLET;
 			 S_PRE_DRAW_BULLET: next_state = S_DRAW_BULLET;
			 S_DRAW_BULLET: next_state = (FrameCounter <= 6'd2) ? S_DRAW_BULLET : S_WAIT_BULLET;			 
			 S_WAIT_BULLET: next_state = (control_freq == 26'd12499999) ? S_ERASE_BULLET : S_WAIT_BULLET;
			 S_ERASE_BULLET: next_state = S_UPDATE_BULLET; 
			 S_UPDATE_BULLET: next_state = S_CONTROLLER_WAIT;			
			// all collision detection and tells you if you lose
			 S_LOSING_MOVE: next_state = (gameover == 1'b1) S_CLEAR_SCREEN : S_WINNING_LOGIC;
			 // not sure if this is in the right spot, this checks game state
			 S_WINNING_LOGIC: next_state = (gamedone == 1'b1) S_END_SCREEN : S_CONTROLLER_WAIT;			 
			 //notice that this is much quicker than the regular freq, this is so that i can update the ship pos
			 //multiple times in between falling block cycles (faster speed for ship this way)
			 S_CONTROLLER_WAIT: next_state = (control_freq == 26'd12500000) ? S_PREP_BULLET : S_CONTROLLER_WAIT;			 
			 S_PRE_ERASE_C: next_state = S_CONTROLLER_ERASE;			 
			 S_CONTROLLER_ERASE: next_state = (FrameCounter <= 6'd54) ? S_CONTROLLER_ERASE : S_CONTROLLER;			 
			 //this is the main freq, when we hit this we must update block position
			 S_CONTROLLER: next_state = (freq == 26'd12499999) ? S_PRE_UPDATE : S_DRAW_CONTROLLER;			 
			 //get ready for new position, update column will now start cycling through the falling blocks to delete them
			 S_PRE_UPDATE: next_state = S_UPDATE_COLUMN;			
			 //now we must clear all those pixels and go load a new box at a different pos
			 S_ERASE: next_state = (FrameCounter <= 4'd15) ? S_ERASE : S_UPDATE_COLUMN; 			 
			 //shift one row down
			 S_UPDATE: next_state = (x_pos < X_MAX && y_pos < 80) ? S_DISPLAY : S_RESET;			 
			 //once we get to the bottom right corner, reset to top left and repeat
			 S_RESET: next_state = S_DISPLAY;

             //VERSION 3

             //VERSION 4

             
			
			
			 
		default: next_state = S_START_SCREEN;
		endcase
		
		
		case (current_state)
			S_START_SCREEN: begin
				y_pos = 7'd0;
				x_pos = 8'd0;
				x_inc = 3'd0;
				y_inc = 3'd0;
				in_colour = 2'b00;
				ClearCounter = 15'd0;
			end
			
			S_CLEAR_SCREEN: begin
				x_pos = ClearCounter[7:0];
				y_pos = ClearCounter[16:8];
				
				ClearCounter = ClearCounter + 1;
				plot_to_vga = 1;
			end
			
			S_PREP_SCREEN: begin
				y_pos = 7'd1;
				x_pos = 8'd30;
				in_colour = 2'b10;
				col_count = 0;	
				row_count = 0;
				FrameCounter = 6'b0;
				freq = 0;
				control_freq = 0;
				control_count = 0;
			end
			
			S_DISPLAY: begin
				
				x_inc <= FrameCounter[1:0];
				y_inc <= FrameCounter[3:2];
				
				FrameCounter <= FrameCounter + 1;
		
				plot_to_vga <= 1;
				y_temp = y_pos;
				
			end
			
			S_UPDATE_COLUMN: begin
				
				col_count = col_count + 1;
				
				if (col_count == 4'd6) begin
					x_pos = 8'd30;
				end
				
				else begin
					x_pos = x_pos + 8'd20;
				end
				
				if(col_count == 4'd6 || col_count == 4'd7 || col_count == 4'd8 || col_count == 4'd9 || col_count == 4'd10) begin
					in_colour = 2'b00;
				end
				
				else begin
					in_colour = in_colour + 2'b01;
				end
				
				FrameCounter = 6'b0;
				
			end
			
			S_UPDATE_ROW: begin
			   in_colour = 3'b010;
				x_pos = 8'd30;
				y_pos = y_pos + 8'd10;
				
				if (erase == 0) begin
					col_count = 0;
				end
				
				else begin
					col_count = 6'd5;
				end
				row_count = row_count + 1;
			end
			
			S_PREP_CONTROLLER: begin
				FrameCounter = 6'b0;
				x_pos = 8'd80;
				x_temp = x_pos;
				y_pos = 7'd100;
				in_colour = 3'b0;
				control_count = 1;
			end
			
			S_DRAW_CONTROLLER: begin
				x_pos = x_temp;
				y_pos = 7'd100;
				
				x_inc = FrameCounter[2:0];
					
				y_inc = FrameCounter[5:3];
				
				if (FrameCounter == 6'd2 || FrameCounter == 6'd3 || FrameCounter == 6'd8 || FrameCounter == 6'd10 || FrameCounter == 6'd11 || FrameCounter == 6'd13 || FrameCounter == 6'd17 || FrameCounter == 6'd18 || FrameCounter == 6'd19 || FrameCounter == 6'd20 || FrameCounter == 6'd23 || FrameCounter == 6'd24 || FrameCounter == 6'd25 || FrameCounter == 6'd28 || FrameCounter == 6'd29) begin
					in_colour = 3'b111;
				end 
				
				else if (FrameCounter == 6'd30 || FrameCounter == 6'd31 || FrameCounter == 6'd32 || FrameCounter == 6'd37 || FrameCounter == 6'd38 || FrameCounter == 6'd39 || FrameCounter == 6'd46) begin
					in_colour = 3'b111;
				end
				
				else if (FrameCounter == 6'd0 || FrameCounter == 6'd5 || FrameCounter == 6'd15 || FrameCounter == 6'd22 || FrameCounter == 6'd26 || FrameCounter == 6'd27 || FrameCounter == 6'd33 || FrameCounter == 6'd34 || FrameCounter == 6'd35 || FrameCounter == 6'd36) begin
					in_colour = 3'b100;
				end
				
				else if (FrameCounter == 6'd16 || FrameCounter == 6'd21) begin
					in_colour = 3'b001;
				end
				
				else begin
					in_colour = 3'b0;
				end
				
				FrameCounter = FrameCounter + 1;
		
				plot_to_vga = 1;
			
			end
			 
			//make sure prep bullet is only hit once
			//make bullet counter
			// every other time, draw bullet
			S_PREP_BULLET: begin
				by_temp = 7'd98;
				bx_temp = x_pos;
			end
			
			S_PRE_DRAW_BULLET: begin
			
			x_pos = bx_temp;
			y_pos = by_temp;
			
			end
			 
			 
			
			/* something i tried for draw_bullet
			S_PREP_CONTROLLER: begin
				FrameCounter = 6'b0;
				x_pos = 8'd80;
				bx_temp = x_pos;
				y_pos = 7'd95;
				in_colour = 3'b0;
				control_count = 1;
			end

			S_DRAW_BULLET: begin
				x_pos = bx_temp;
				y_pos = by_temp;
					
				y_inc = FrameCounter[5:3];
				
				if (FrameCounter == 6'd2) begin
					in_colour = 3'b111;
				end 
				
				FrameCounter = FrameCounter + 1;
		
				plot_to_vga = 1;
			
			end
			*/
			 
			 
			 
			 
			 S_DRAW_BULLET: begin
				if(~shoot)
				plot_to_vga = 1;
			 
			 end
			 
			 S_WAIT_BULLET: begin
				plot_to_vga = 0;
				control_freq = control_freq + 1;
				freq = freq + 1;
			end
			 
			 //S_PRE_ERASE_BULLET: next_state = S_ERASE_BULLET;
			 
			 S_ERASE_BULLET: begin
				erase = 1;
			 
			 end
			 
			 S_UPDATE_BULLET: begin
				by_temp = y_pos - 1;
				y_pos = 7'd100;
			 end

			 S_LOSING_MOVE: begin
				if ((by_temp == y_row1) && ((bx_temp <= 42 && bx_temp >= 30) || (bx_temp <= 64 && bx_temp >= 52) || (bx_temp <= 108 && bx_temp >= 96) || (bx_temp <= 130 && bx_temp >= 118)) && 1done == 1'b0) begin
					gameover = 1'b1;
				end
				if ((((by_temp == y_row1) && ((bx_temp <= 64 && bx_temp >= 52) || (bx_temp <= 108 && bx_temp >= 96) || (bx_temp <= 130 && bx_temp >= 118))) || ((by_temp == y_row2) && (bx_temp <= 86 && bx_temp >= 74))) && 2done == 1'b0) begin
					gameover = 1'b1;
				end
				if ((((by_temp == y_row1) && ((bx_temp <= 64 && bx_temp >= 52) || (bx_temp <= 130 && bx_temp >= 118))) || ((by_temp == y_row2) && ((bx_temp <= 86 && bx_temp >= 74) || (bx_temp <= 42 && bx_temp >= 30)))) && 3done == 1'b0) begin
					gameover = 1'b1;
				end
				if ((((by_temp == y_row1) && ((bx_temp <= 64 && bx_temp >= 52))) || ((by_temp == y_row2) && ((bx_temp <= 86 && bx_temp >= 74) || (bx_temp <= 42 && bx_temp >= 30)|| (bx_temp <= 108 && bx_temp >= 96)))) && 4done == 1'b0) begin
					gameover = 1'b1;
				end
				if ((((by_temp == y_row1) && ((bx_temp <= 64 && bx_temp >= 52))) || ((by_temp == y_row2) && ((bx_temp <= 42 && bx_temp >= 30) || (bx_temp <= 108 && bx_temp >= 96) || (bx_temp <= 130 && bx_temp >= 118)))) && 5done == 1'b0) begin
					gameover = 1'b1;
				end
				if (((by_temp == y_row3) && ((bx_temp <= 86 && bx_temp >= 74))) || ((by_temp == y_row2) && ((bx_temp <= 42 && bx_temp >= 30) || (bx_temp <= 130 && bx_temp >= 118) || (bx_temp <= 108 && bx_temp >= 96))) && 6done == 1'b0) begin
					gameover = 1'b1;
				end
				if ((((by_temp == y_row3) && ((bx_temp <= 86 && bx_temp >= 74))) || ((by_temp == y_row2) && ((bx_temp <= 64 && bx_temp >= 52) || (bx_temp <= 108 && bx_temp >= 96) || (bx_temp <= 130 && bx_temp >= 118)))) && 7done == 1'b0) begin
					gameover = 1'b1;
				end
				if ((((by_temp == y_row3) && ((bx_temp <= 86 && bx_temp >= 74) || (bx_temp <= 42 && bx_temp >= 30))) || ((by_temp == y_row2) && ((bx_temp <= 64 && bx_temp >= 52) || (bx_temp <= 130 && bx_temp >= 118)))) && 8done == 1'b0) begin
					gameover = 1'b1;
				end
				if ((((by_temp == y_row3) && ((bx_temp <= 86 && bx_temp >= 74) || (bx_temp <= 42 && bx_temp >= 30) || (bx_temp <= 108 && bx_temp >= 96))) || ((by_temp == y_row2) && ((bx_temp <= 64 && bx_temp >= 52)))) && 9done == 1'b0) begin
					gameover = 1'b1;
				end
				if ((((by_temp == y_row3) && ((bx_temp <= 42 && bx_temp >= 30) || (bx_temp <= 108 && bx_temp >= 96) || (bx_temp <= 130 && bx_temp >= 118))) || ((by_temp == y_row2) && ((bx_temp <= 64 && bx_temp >= 52)))) && gamedone == 1'b0) begin
					gameover = 1'b1;
				end
				if (by_temp == 1) begin
					gameover = 1'b1;
				end
			 end 

			 S_WINNING_LOGIC: begin
				1done = 1'b0;
				2done = 1'b0;
				3done = 1'b0;
				4done = 1'b0;
				5done = 1'b0;
				6done = 1'b0;
				7done = 1'b0;
				8done = 1'b0;
				9done = 1'b0;
				gamedone = 1'b0;
				if ((by_temp == (y_row1 || y_row2 || y_row3)) && (bx_temp <= 86 && bx_temp >= 74)) begin
					1done = 1'b1;
				end
				if ((by_temp == (y_row1 || y_row2 || y_row3)) && (bx_temp <= 42 && bx_temp >= 30) && 1done == 1'b1) begin
					2done = 1'b1;
				end
				if ((by_temp == (y_row1 || y_row2 || y_row3)) && (bx_temp <= 108 && bx_temp >= 96) && 2done == 1'b1) begin
					3done = 1'b1;
				end
				if ((by_temp == (y_row1 ||y_row2 || y_row3)) && (bx_temp <= 130 && bx_temp >= 108) && 3done == 1'b1) begin
					4done = 1'b1;
				end
				if ((by_temp == (y_row2 || y_row3)) && (bx_temp <= 86 && bx_temp >= 74) && 4done == 1'b1) begin
					5done = 1'b1;
				end
				if ((by_temp == (y_row1 || y_row2 || y_row3)) && (bx_temp <= 64 && bx_temp >= 52) && 5done == 1'b1) begin
					6done = 1'b1;
				end
				if ((by_temp == (y_row2 || y_row3)) && (bx_temp <= 42 && bx_temp >= 30) && 6done == 1'b1) begin
					7done = 1'b1;
				end
				if ((by_temp == (y_row2 || y_row3)) && (bx_temp <= 108 && bx_temp >= 96) && 7done == 1'b1) begin
					8done = 1'b1;
				end
				if ((by_temp == (y_row2 || y_row3)) && (bx_temp <= 130 && bx_temp >= 118) && 8done == 1'b1) begin
					9done = 1'b1;
				end
				if ((by_temp == y_row3) && (bx_temp <= 86 && bx_temp >= 74) && 9done == 1'b1) begin
					gamedonedone = 1'b1;
				end
			 end
			
			//VERSION 2
			S_CONTROLLER_WAIT: begin
				plot_to_vga = 1;
				FrameCounter = 6'b0;
				//in_colour = 3'b0;
			end

			
			S_PRE_ERASE_C: begin
				erase = 1;
			end
			
			S_CONTROLLER_ERASE: begin
				
				x_inc = FrameCounter[2:0];
					
				y_inc = FrameCounter[5:3];
				
				FrameCounter = FrameCounter + 1;
				
				erase = 1;
				in_colour = 3'b0;
				plot_to_vga = 1;
			
			end
			
			S_CONTROLLER: begin
				plot_to_vga = 0;
				FrameCounter = 0;
				control_freq = 0;
				in_colour = 3'b0;
				
				if (~ld_right)
					x_pos = x_pos + 3;
				if (~ld_left) 
					x_pos = x_pos - 3;
				else
					x_pos = x_pos;
					
				x_temp = x_pos;
			end
				
			S_PRE_UPDATE: begin
				x_pos = 8'd30;
				y_pos = y_temp - 8'd20;
				plot_to_vga = 1;
				row_count = 2'd2;
				//freq = freq + 1;
				
				in_colour = 3'b0;
			end
			
			S_ERASE: begin
			
				x_inc = FrameCounter[1:0];
				y_inc = FrameCounter[3:2];
				
				FrameCounter = FrameCounter + 1;
				
				erase = 1;
				plot_to_vga = 1;
				
			end
			
			S_UPDATE: begin
			   erase = 0;
			   col_count = 0;
				row_count = 0;
				update = 1;
				in_colour = 3'b001;
				x_pos = 8'd30;
				y_pos = y_pos - 8'd19;
				
				freq = 0;
				FrameCounter = 6'b0;
			end
			
			S_RESET: begin
				y_pos = 7'b0;
				x_pos = 8'd30;
				in_colour = 2'b10;
				
				FrameCounter = 6'b0;
				freq = 0;
				erase = 0;
			end
		endcase
		
	
		if (~Reset_n)
			current_state = S_START_SCREEN;
		else
			current_state = next_state;
    end

endmodule

module DataPath (iClock, iReset_n, plot_to_vga, erase, update, iColour, x, y, oColour, x_pos, y_pos, x_inc, y_inc);

	 input iClock, iReset_n, plot_to_vga, erase, update;
    input [2:0] x_inc, y_inc;
	 
    input [2:0] iColour;
    input wire [7:0] x_pos;
	 input wire [6:0] y_pos;

    output [2:0] oColour;
    output [7:0] x;
    output [6:0] y;

    reg [7:0] reg_x;
    reg [6:0] reg_y;
	 
    reg [2:0] reg_c;

    always @(posedge iClock)
    begin
        if (~iReset_n) begin
            reg_x <= 8'b0;
            reg_y <= 7'b0;
            reg_c <= 2'b0;
        end
        else begin
            if (plot_to_vga) begin
                reg_x = x_pos;
                reg_y = y_pos;
				end
					 if (erase)
						reg_c = 2'b00;
					 else
						reg_c = iColour;
        end
    end

    assign x = reg_x + x_inc;
    assign y = reg_y + y_inc;
    assign oColour = reg_c;

endmodule

/*
module bullet_control(iClock, iReset_n, shoot, hit, flying, startX, startY, rocketX, rocketY);

input iClock, iReset_n, shoot, hit
output reg flying;
output reg [7:0] rocketX;
output reg [6:0] rocketY;
reg speed, rockethit;



always@(posedge iClock or posedge iReset_n)
    begin
        if(iReset_n)
        begin
            rockethit <= 0;
        end else if (shoot)
        begin //partial boundaries
			plot_bullet <= 1'b1;
            if( ((flying && red) && ((rocketX >= red - 6)&&(rocketX <= red + 6))&&(rocketY == red + 10))||
                ((flying && yellow) && ((rocketX >= yellow - 6)&&(rocketX <= yellow + 6))&&(rocketY == yellow + 10))||
                ((flying && green) && ((rocketX >= green - 6)&&(rocketX <= green + 6))&&(rocketY == green + 10))||
                ((flying && blue) && ((rocketX >= blue - 6)&&(rocketX <= blue + 6))&&(rocketY == blue + 10))||
                ((flying && purple) && ((rocketX >= purple - 6)&&(rocketX <= purple + 6))&&(rocketY == purple + 10)))
            begin 
                rockethit <= 1'b1;
            end else begin
                rockethit <= 0;
            end      
        end
    end

always @(posedge iClock or posedge rest)
begin
	if(rst)
	begin
		flying <= 0;
	end else
	begin
		if(shoot)
		begin
			if (flying == 0) begin
				flying <= 1;
				rocketX <= startX + 10'd1
				rocketY <= startY;
				plot_bullet <= 1'b1;
			end
		end
		if(flying)
		begin
			//rocketY <= direction ? (rocketY - speed):(rocketY + speed);
			if((rocketY == 7'd0) || hit || rockethit)
			begin
				flying <= 0;
			end
		end
	end
end

/*
always@(posedge iClock)
        if(flying)
        begin
            if(counter == 24'd150_000)begin
                 speed <= 1'b1;
                 counter <= 0;
            end else begin
                 counter <= counter + 1'b1;
                 speed <= 0;
            end
        end else begin
            counter <= 0;
            speed <= 0;
        end
		*/
/*


endmodule

module bullet_datapath(iClock, iReset_n, bullet_posx, bullet_posy, plot_bullet, erase_bullet, iColour, bx_inc, by_inc, bullet_x, bullet_y, bullet_c);

	input iClock, iReset_n, plot_bullet, erase_bullet;
	input [1:0] bx_inc, by_inc;

	input [3:0] iColour;
	output [7:0] bullet_posx;
	output [6:0] bullet_posy;
	output [3:0] bullet_finalc;

	reg [7:0] bullet_x;
	reg [6:0] bullet_y;
	reg [3:0] bullet_c; 

always @(posedge iClock)
	begin
		if (plot_bullet) begin
			bullet_x <= ship_posx;
			bullet_y <= ship_posy - 1;
			bullet_c <= 3'b111;
		end
		if (erase_bullet)
			bullet_c <= 3'b000;
		else
			bullet_c <= iColour;
	end

	assign bullet_posx = bullet_x;
	assign bullet_posy = bullet_y;
	assign bullet_finalc = bullet_c;

endmodule

*/