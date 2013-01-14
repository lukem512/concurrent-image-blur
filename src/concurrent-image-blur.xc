/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20600 - WEEKS 9 to 12
// ASSIGNMENT 3
// CODE SKELETON
// TITLE: "Concurrent Image Filter"
//
/////////////////////////////////////////////////////////////////////////////////////////
typedef unsigned char uchar;

#include <platform.h>
#include <stdio.h>
#include "pgmIO.h"

// Image dimensions
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
//#define INFNAME "O:\\test0.pgm"
//#define OUTFNAME "O:\\test0.pgm"

// LED ports
out port ledport[4] = { PORT_CLOCKLED_0, PORT_CLOCKLED_1, PORT_CLOCKLED_2, PORT_CLOCKLED_3 };

// Button port
in port buttons = PORT_BUTTON;

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

void visualiser(chanend c_collector, chanend c_quadrant[]) {
	unsigned int threshold, leds, counter;
	int val, running = 1;

	// Compute threshold
	threshold = (IMWD * IMHT) / 12;

	// Initialise to all LEDs off
	// TODO
	leds = 0;

	counter = 0;
	while (running) {
		// Receive value
		c_collector :> val;

		if (val == SHUTDOWN) {
			// Send to showLED threads
			for (int i = 0; i < 4; i++) {
				c_quadrant[i] <: SHUTDOWN;
			}

			// Shutdown thread
			running = 0;
		} else {
			// Increment counter
			counter++;

			// Need to illuminate another LED?
			if (counter == threshold) {
				// TODO - illuminate another LED
				leds++;

				// Reset counter
				counter = 0;
			}
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
void buttonListener (in port buttons, chanend c_stream) {
	int buttonInput;
	int running = 1;

	while (running) {
		buttons when pinsneq(15) :> buttonInput;

		c_stream <: buttonInput;

		if (buttonInput == ButtonC) {
			running = 0;
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
	printf( "DataInStream:Done...\n" );
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
		//printf ("\n\nProcessImage:Line %d\n\n", y);

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
			//printf ("ProcessImage:First line...\n");
			for (int i = 0; i < IMWD; i++) {
				c_out <: (uchar)(BLACK);
			}
			//printf ("ProcessImage:Done!\n");
		}

		// SUBSEQUENT LINES
		// This does nothing for second, as 3 lines need to be stored first
		if (y > 1) {
			pixel_idx = 0;
			while (pixel_idx != IMWD) {
				// Retrieve value from each worker
				// and send it to output
				for (int i = 0; i < workers_in_use; i++) {
					//printf ("ProcessImage:Waiting for worker %d...\n", i);
					c_workers[i] :> val;
					//printf ("ProcessImage:Done!\n");
					c_out <: (uchar)(val);
				}
				workers_in_use = 0;

				// Give each worker a new pixel
				for (int i = 0; i < MAX_WORKERS; i++) {
					// Are we on a boundary?
					boundary = 0;
					if (pixel_idx == 0 || pixel_idx == (IMWD - 1)) {
						//printf ("ProcessImage:Boundary pixel\n");
						boundary = 1;
					}

					//printf ("ProcessImage:Sending to worker %d...\n", i);

					// Send boundary value
					//printf ("ProcessImage:Boundary flag\n");
					c_workers[i] <: boundary;

					// Send pixel value
					if (!boundary) {
						// Previous line
						//printf ("ProcessImage:1\n");
						c_workers[i] <: line[prev_line(line_idx)][pixel_idx-1];
						//printf ("ProcessImage:2\n");
						c_workers[i] <: line[prev_line(line_idx)][pixel_idx];
						//printf ("ProcessImage:3\n");
						c_workers[i] <: line[prev_line(line_idx)][pixel_idx+1];

						// Current line
						//printf ("ProcessImage:4\n");
						c_workers[i] <: line[cur_line(line_idx)][pixel_idx-1];
						//printf ("ProcessImage:5\n");
						c_workers[i] <: line[cur_line(line_idx)][pixel_idx];
						//printf ("ProcessImage:6\n");
						c_workers[i] <: line[cur_line(line_idx)][pixel_idx+1];

						// Next line
						//printf ("ProcessImage:7\n");
						c_workers[i] <: line[line_idx][pixel_idx-1];
						//printf ("ProcessImage:8\n");
						c_workers[i] <: line[line_idx][pixel_idx];
						//printf ("ProcessImage:9\n");
						c_workers[i] <: line[line_idx][pixel_idx+1];
					}

					//printf ("ProcessImage:Done\n");

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
				c_out <: (uchar)(val);

				// Shutdown the worker threads
				c_workers[i] <: SHUTDOWN;
			}

			for (int i = 0; i < IMWD; i++) {
				c_out <: (uchar)(BLACK);
			}

			//printf ("ProcessImage:Done\n");
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
		//printf ("Worker:Waiting for boundary flag\n");
		c_dist :> boundary;

		// Shutdown received?
		if (boundary == SHUTDOWN) {
			running = 0;
			break;
		}

		// Initialise blurred with black
		blurred = BLACK;

		//printf ("Worker:Computing value\n");

		if (!boundary) {
			//printf ("Worker:Not boundary!\n");
			for (int i = 0; i < NEIGHBOURS; i++) {
				//printf ("Worker:Waiting for value %d\n", i+1);
				c_dist :> val;
				//printf ("Worker:Received value #%d (%d) from channel\n", i+1, val);
				blurred += val;
			}

			// calculate the average
			blurred = blurred / NEIGHBOURS;

			// avoid uchar overflow
			if (blurred > 255)
				blurred = 255;
		}

		//printf ("Worker:Writing value (%d) to channel\n\n", blurred);

		// Return blurred value
		c_dist <: ((uchar) blurred);
	}

	printf ("Worker:Shutting down...\n");
	return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to pgm image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in, chanend c_visualiser) {
	int res;

	uchar line[IMWD];

	printf("DataOutStream:Start...\n");

	res = _openoutpgm(outfname, IMWD, IMHT);

	if (res) {
		printf("DataOutStream:Error opening %s\n.", outfname);
		return;
	}

	for (int y = 0; y < IMHT; y++) {
		for (int x = 0; x < IMWD; x++) {
			// Receive pixel from distributor
			c_in :> line[x];

			// Update clock visualisation
			// TODO
			}

		_writeoutline( line, IMWD );
	}

	// Tell visualiser to shutdown
	c_visualiser <: SHUTDOWN;

	_closeoutpgm();
	printf( "DataOutStream:Done...\n" );
	return;
}

//MAIN PROCESS defining channels, orchestrating and starting the threads
int main() {
	chan c_inIO, c_outIO; //extend your channel definitions here
	chan c_workers[MAX_WORKERS];
	chan c_quadrant[4];
	chan c_visualiser, c_buttonlistener;

	par {
		on stdcore[0]: DataInStream(INFNAME, c_inIO);
		on stdcore[1]: DataOutStream(OUTFNAME, c_outIO, c_visualiser);

		on stdcore[2]: distributor(c_inIO, c_outIO, c_workers, c_buttonlistener);
		on stdcore[3]: visualiser(c_visualiser, c_quadrant);
		on stdcore[0]: buttonListener(buttons, c_buttonlistener);

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
