/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20600 - WEEKS 9 to 12
// ASSIGNMENT 3
// CODE SKELETON WITH EXTENSIONS
// TITLE: "Concurrent Image Filter"
// AUTHORS: Luke Mitchell <lm0466> and Joe Bligh
//
/////////////////////////////////////////////////////////////////////////////////////////
typedef unsigned char uchar;

#include <platform.h>
#include <stdio.h>
#include "platform.h"
#include "pgmIO.h"

// Image dimensions
//#define IMHT 256
//#define IMWD 400
#define IMHT 16
#define IMWD 16

// Number of neighbours to blur
#define NEIGHBOURS 9

// Colour black as a uchar value
#define BLACK 0

// The maximum number of workers to spawn
#define MAX_WORKERS 16

// The number of lines of the image to store
#define LINES_STORED 3

// Message to shutdown worker
#define SHUTDOWN -1

// Button defines
#define NoButton 0
#define ButtonA 14
#define ButtonB 13
#define ButtonC 11
#define ButtonD 7

// The input and output filenames
#define INFNAME "test/test0.pgm"
#define OUTFNAME "test/test0out.pgm"
//#define INFNAME "test/BristolCathedral.pgm"
//#define OUTFNAME "test/BristolCathedralout.pgm"
//#define INFNAME "O:\\test0.pgm"
//#define OUTFNAME "O:\\test0.pgm"

// LED ports
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;
out port bled 	= PORT_BUTTONLED;
out port ledport[4] = { PORT_CLOCKLED_0, PORT_CLOCKLED_1, PORT_CLOCKLED_2, PORT_CLOCKLED_3 };

// Button port
in port buttons = PORT_BUTTON;

// TODO
// * Timer process
// * CSP
// * Report
// * Button C should shut down at any point
// * Debounce pause!

/////////////////////////////////////////////////////////////////////////////////////////
//
// Keeps track of the total run time of the program in ms
// Ref: https://www.xmos.com/node/14806?page=1
//
/////////////////////////////////////////////////////////////////////////////////////////
/*void clock(chanend c_collector) {
	unsigned int ms, time;
	unsigned int millisecond = 100000; // 1ms
	int running = 1;
	timer t;

	// get the time
	t :> time;

	while (running) {
		time += millisecond;
		t when timerafter(time) :> time;
		ms += 1;

		// TODO - check for shutdown
	}

	printf( "clock:Shutting down...\n" );
	return;
}*/

/////////////////////////////////////////////////////////////////////////////////////////
//
// Displays an LED pattern in one quadrant of the clock LEDs
//
/////////////////////////////////////////////////////////////////////////////////////////
void showLED(out port p, chanend c_visualiser) {
	unsigned int lightUpPattern;
	unsigned int running = 1;
	while (running) {
		// Read LED pattern from visualiser process
		c_visualiser :> lightUpPattern;

		if (lightUpPattern == SHUTDOWN) {
			// Shutdown thread
			running = 0;
		} else {
			// Send pattern to LEDs
			p <: lightUpPattern;
		}
	}

	printf( "ShowLED:Shutting down...\n" );
	return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Turn off all clock LEDs.
// To be called from visualiser ONLY.
//
/////////////////////////////////////////////////////////////////////////////////////////
void deluminate_clock_leds (chanend c_quadrant[]) {
	for (int i = 0; i < 4; i++) {
		c_quadrant[i] <: 0;
	}
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Turn off all button LEDs
// To be called from visualiser ONLY.
//
///////////////////////////////////////////////////////////////////////////////////////////
void deluminate_button_leds () {
	bled <: 0b0000;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Turn off all LEDs
// To be called from visualiser ONLY.
//
/////////////////////////////////////////////////////////////////////////////////////////
void deluminate_leds (chanend c_quadrant[]) {
	deluminate_clock_leds(c_quadrant);
	deluminate_button_leds();
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Set the clock LEDs to red
// To be called from visualiser ONLY.
//
/////////////////////////////////////////////////////////////////////////////////////////
void set_led_colour_red () {
	cledG <: 0;
	cledR <: 1;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Set the clock LEDs to green.
// To be called from visualiser ONLY.
//
/////////////////////////////////////////////////////////////////////////////////////////
void set_led_colour_green () {
	cledR <: 0;
	cledG <: 1;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Updates the LEDs on the clock and for the buttons
//
/////////////////////////////////////////////////////////////////////////////////////////
void visualiser(chanend c_buttonListener, chanend c_collector, chanend c_quadrant[]) {
	unsigned int leds;
	int val, running = 1, paused = 0, complete = 0;
	int lightUpPattern[12];

	// Compute lightUpPattern array
	for (int i = 0; i < 12; i++) {
		lightUpPattern[i] = 16<<(i%3);
	}

	// Initialise all LEDs to off
	deluminate_leds(c_quadrant);

	// Start and shutdown LEDs
	bled <: 0b0101;

	// Wait for indication that processing has begun
	c_buttonListener :> val;

	// Turn off start LED and turn on pause LED
	bled <: 0b0110;

	// Select green LED
	set_led_colour_green ();

	// Set LED illuminated counter to 0
	leds = 0;

	// Run!
	while (running) {
		// Receive value
		select {
			case c_collector :> val:

				if (val == SHUTDOWN) {
					// Turn LEDs off
					deluminate_leds(c_quadrant);

					// Send to showLED threads
					for (int i = 0; i < 4; i++) {
						c_quadrant[i] <: SHUTDOWN;
					}

					// Shutdown thread
					running = 0;
				} else {
					// illuminate the appropriate number of LEDs
					switch (leds) {
						case 1:
							c_quadrant[0] <: lightUpPattern[0];
							break;

						case 2:
							c_quadrant[0] <: lightUpPattern[0] + lightUpPattern[1];
							break;

						case 3:
							c_quadrant[0] <: lightUpPattern[0] + lightUpPattern[1] + lightUpPattern[2];
							break;

						case 4:
							c_quadrant[1] <: lightUpPattern[3];
							break;

						case 5:
							c_quadrant[1] <: lightUpPattern[3] + lightUpPattern[4];
							break;

						case 6:
							c_quadrant[1] <: lightUpPattern[3] + lightUpPattern[4] + lightUpPattern[5];
							break;

						case 7:
							c_quadrant[2] <: lightUpPattern[6];
							break;

						case 8:
							c_quadrant[2] <: lightUpPattern[6] + lightUpPattern[7];
							break;

						case 9:
							c_quadrant[2] <: lightUpPattern[6] + lightUpPattern[7] + lightUpPattern[8];
							break;

						case 10:
							c_quadrant[3] <: lightUpPattern[9];
							break;

						case 11:
							c_quadrant[3] <: lightUpPattern[9] + lightUpPattern[10];
							break;

						case 12:
							c_quadrant[3] <: lightUpPattern[9] + lightUpPattern[10] + lightUpPattern[11];

							// Set flag to indicate completeness
							complete = 1;

							// Turn off pause LED
							bled <: 0b0100;
							break;

						default:
							// Do nothing
							break;
					}

					// Increment LEDs counter
					leds++;
				}
				break;

			case c_buttonListener :> val:
					paused = !paused;

					// Set colours appropriately
					if (paused && !complete) {
						set_led_colour_red ();
					} else {
						set_led_colour_green ();
					}
				break;
		}
	}

	printf( "Visualiser:Shutting down...\n" );
	return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Handles button presses
//
/////////////////////////////////////////////////////////////////////////////////////////
void buttonListener (in port buttons, chanend c_visualiser, chanend c_distributor) {
	int buttonInput;
	int running = 1, started = 0;

	while (running) {
		buttons when pinsneq(15) :> buttonInput;

		c_distributor <: buttonInput;

		// act on input?
		switch (buttonInput) {
			case ButtonA:
				// Inform visualiser
				if (!started) {
					c_visualiser <: 1;
				}

				// Set started flag
				started = 1;
				break;

			case ButtonB:
				if (started) {
					// let visualiser change LED colour
					c_visualiser <: 1;
				}
				break;

			case ButtonC:
				// shutdown!
				running = 0;

				// tell visualuser to begin, so it can receive shutdown
				if (!started) {
					c_visualiser <: 1;
				}
				break;

			default:
				break;
		}
	}

	printf( "ButtonListener:Shutting down...\n" );
	return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from pgm file with path and name infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend c_out) {
	int res;
	int val;
	uchar line[IMWD];

	printf("DataInStream:Start...\n");

	res = _openinpgm(infname, IMWD, IMHT);

	if (res) {
		printf("DataInStream:Error opening %s\n.", infname);
		return;
	}

	for (int y = 0; y < IMHT; y++) {
		_readinline(line, IMWD);

		for (int x = 0; x < IMWD; x++) {
			// Send pixel value to distributor
			c_out <: line[ x ];
		}
	}

	_closeinpgm();
	printf( "DataInStream:Shutting down...\n" );
	return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Returns the index of the second line stored in the lines array
//
/////////////////////////////////////////////////////////////////////////////////////////
int cur_line (int line_idx) {
	if (line_idx == 0)
		return LINES_STORED - 1;
	else
		return line_idx - 1;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Returns the index of the first line stored in the lines array
//
/////////////////////////////////////////////////////////////////////////////////////////
int prev_line (int line_idx) {
	int current_line = cur_line (line_idx);

	if (current_line == 0)
		return LINES_STORED - 1;
	else
		return current_line - 1;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to farm out parts of the image...
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out, chanend c_workers[], chanend c_buttonlistener) {
	uchar val;
	uchar line[LINES_STORED][IMWD];
	int boundary;
	int line_idx = 0;
	int pixel_idx = 0;
	int workers_in_use = 0;
	int started = 0;
	int ended = 0;
	int paused = 0;
	int x;
	int buttonValue;

	// Wait for button A to be pressed to begin reading
	while (!started) {
		c_buttonlistener :> buttonValue;

		if (buttonValue == ButtonA) {
			started = 1;
		}
	}

	printf("ProcessImage:Start, size = %dx%d\n", IMHT, IMWD);

	// For every line in the image
	for (int y = 0; y < IMHT; y++) {
		// Retrieve each pixel in the line
		x = 0;
		while ( x < IMWD) {
			// check for pause
			select {
				case c_buttonlistener :> buttonValue:
					if (buttonValue == ButtonB) {
						paused = !paused;
					}
					break;

				default:
					break;
			}

			// Receive pixel
			if (!paused) {
				c_in :> line[line_idx][x];
				x++;
			}
		}

		// FIRST LINE
		if (y == 0) {
			for (int i = 0; i < IMWD; i++) {
				c_out <: 0;
				c_out <: (uchar)(BLACK);
			}
		}

		// SUBSEQUENT LINES
		// This does nothing for second, as 3 lines need to be stored first
		if (y > 1) {
			pixel_idx = 0;
			while (pixel_idx != IMWD) {
				// Retrieve value from each worker
				// and send it to output
				for (int i = 0; i < workers_in_use; i++) {
					c_workers[i] :> val;
					c_out <: 0;
					c_out <: (uchar)(val);
				}
				workers_in_use = 0;

				// Give each worker a new pixel
				for (int i = 0; i < MAX_WORKERS; i++) {
					// Are we on a boundary?
					boundary = 0;
					if (pixel_idx == 0 || pixel_idx == (IMWD - 1)) {
						boundary = 1;
					}

					// Send boundary value
					c_workers[i] <: boundary;

					// Send pixel value
					if (!boundary) {
						// Previous line
						c_workers[i] <: line[prev_line(line_idx)][pixel_idx-1];
						c_workers[i] <: line[prev_line(line_idx)][pixel_idx];
						c_workers[i] <: line[prev_line(line_idx)][pixel_idx+1];

						// Current line
						c_workers[i] <: line[cur_line(line_idx)][pixel_idx-1];
						c_workers[i] <: line[cur_line(line_idx)][pixel_idx];
						c_workers[i] <: line[cur_line(line_idx)][pixel_idx+1];

						// Next line
						c_workers[i] <: line[line_idx][pixel_idx-1];
						c_workers[i] <: line[line_idx][pixel_idx];
						c_workers[i] <: line[line_idx][pixel_idx+1];
					}

					// Increment worker counter
					workers_in_use++;

					// Increment pixel index
					pixel_idx++;

					// Break if needed
					if (pixel_idx == IMWD) {
						break;
					}
				}
			}
		}

		// LAST LINE
		if (y == IMHT-1) {
			//printf("ProcessImage:Last line...\n");
			for (int i = 0; i < workers_in_use; i++) {
				c_workers[i] :> val;
				c_out <: 0;
				c_out <: (uchar)(val);

				// Shutdown the worker threads
				// TODO - maybe move this to below shutdown?
				c_workers[i] <: SHUTDOWN;
			}

			for (int i = 0; i < IMWD; i++) {
				c_out <: 0;
				c_out <: (uchar)(BLACK);
			}
		}

		// Increment the line index, in a circular manner
		line_idx = (line_idx + 1) % LINES_STORED;
	}

	// Wait for button C to shutdown
	while (!ended) {
		c_buttonlistener :> buttonValue;

		if (buttonValue == ButtonC) {
			ended = 1;
		}
	}

	// Tell collector to shutdown
	c_out <: 1;

	printf("ProcessImage:Shutting down...\n");
	return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Worker thread
//
/////////////////////////////////////////////////////////////////////////////////////////
void worker(chanend c_dist) {
	uchar val;
	int blurred;
	int boundary;
	int running = 1;

	while (running) {
		// Receive boundary flag
		c_dist :> boundary;

		// Shutdown received?
		if (boundary == SHUTDOWN) {
			running = 0;
			break;
		}

		// Initialise blurred with black
		blurred = BLACK;

		if (!boundary) {
			for (int i = 0; i < NEIGHBOURS; i++) {
				c_dist :> val;
				blurred += val;
			}

			// calculate the average
			blurred = blurred / NEIGHBOURS;

			// avoid uchar overflow
			if (blurred > 255)
				blurred = 255;
		}

		// Return blurred value
		c_dist <: ((uchar) blurred);
	}

	printf ("Worker:Shutting down...\n");
	return;
}

void collector (chanend c_in, chanend c_out, chanend c_visualiser) {
	int running, shutdown;
	unsigned int threshold, counter;
	uchar val;

	// Compute threshold for LEDs
	threshold = (IMWD * IMHT) / 12;

	// Intialise counter to nothing
	counter = 0;

	// Send first visualiser message
	c_visualiser <: 1;

	// Receive worker data
	running = 1;
	shutdown = 0;
	while (running) {
		// Shutdown?
		c_in :> shutdown;

		if (shutdown) {
			// Set shutdown flag
			running = 0;
		} else {
			// Receive pixel value
			c_in :> val;

			// Increment counter
			counter++;

			// Update clock visualisation?
			if (counter == threshold) {
				c_visualiser <: 1;
				counter = 0;
			}

			c_out <: 0;
			c_out <: val;
		}
	}

	// Tell visualiser to terminate
	c_visualiser <: SHUTDOWN;

	printf ("Collector:Shutting down...\n");
	return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to pgm image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in) {
	int res, shutdown;
	uchar val;
	uchar line[IMWD];

	printf("DataOutStream:Start...\n");

	// Open the output file
	res = _openoutpgm(outfname, IMWD, IMHT);

	if (res) {
		printf("DataOutStream:Error opening %s\n.", outfname);
		return;
	}

	// Retrieve output image pixels
	shutdown = 0;
	for (int y = 0; y < IMHT; y++) {
		for (int x = 0; x < IMWD; x++) {
			// Receive pixel from distributor
			c_in :> shutdown;
			c_in :> val;

			// Check for shutdown message
			if (shutdown) {
				break;
			} else {
				line[x] = val;
			}
		}

		// Shutdown?
		if (shutdown) {
			break;
		}

		// Write the line to file
		_writeoutline( line, IMWD );
	}

	// Close output file
	_closeoutpgm();

	printf( "DataOutStream:Shutting down...\n" );
	return;
}

//MAIN PROCESS defining channels, orchestrating and starting the threads
int main() {
	chan c_inIO, c_outIO, c_collectIO;
	chan c_workers[MAX_WORKERS];
	chan c_quadrant[4];
	chan c_visualiser, c_buttonlistener, c_visualiserListener;

	par {
		on stdcore[2]: DataInStream(INFNAME, c_inIO);
		on stdcore[1]: distributor(c_inIO, c_collectIO, c_workers, c_buttonlistener);
		on stdcore[2]: collector(c_collectIO, c_outIO, c_visualiser);
		on stdcore[3]: DataOutStream(OUTFNAME, c_outIO);

		on stdcore[0]: visualiser(c_visualiserListener, c_visualiser, c_quadrant);
		on stdcore[0]: buttonListener(buttons, c_visualiserListener, c_buttonlistener);

		// Replication of workers
		par (int k=0;k<MAX_WORKERS;k++) {
			on stdcore[k%4]: worker(c_workers[k]);
		}

		// Replication for visualisation
		par (int k=0;k<4;k++) {
			on stdcore[k%4]: showLED(ledport[k], c_quadrant[k]);
		}
	}

	// Return success
	return 0;
}
