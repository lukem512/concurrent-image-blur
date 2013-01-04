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
#define MAX_WORKERS 8

// The number of lines of the image to store
#define LINES_STORED 3

// Message to shutdown worker
#define SHUTDOWN -1

// The input and output filenames
#define INFNAME "test/test0.pgm"
#define OUTFNAME "test/testout.pgm"
//#define INFNAME "O:\\test0.pgm"
//#define OUTFNAME "O:\\test0.pgm"

/////////////////////////////////////////////////////////////////////////////////////////
//
// Method to blur a pixel given it's eight neighbouring pixels
//
/////////////////////////////////////////////////////////////////////////////////////////
uchar blur(uchar neighbours[NEIGHBOURS], int boundary) {
	int blurred;

	// Set initial value to black
	// this will not be changed if the pixel is a boundary value
	blurred = BLACK;

	if (!boundary) {
		// Set to average of values
		for (int i = 0; i < NEIGHBOURS; i++)
			blurred += neighbours[i];

		blurred = blurred / NEIGHBOURS;

		// avoid uchar overflow
		if (blurred > 255)
			blurred = 255;
	}

	return (uchar) blurred;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from pgm file with path and name infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend c_out) {
	int res;
	uchar line[IMWD];

	printf("DataInStream:Start...\n");

	res = _openinpgm(infname, IMWD, IMHT);

	if (res) {
		printf("DataInStream:Error openening %s\n.", infname);
		return;
	}

	for (int y = 0; y < IMHT; y++) {
		_readinline(line, IMWD);

		for (int x = 0; x < IMWD; x++) {
			c_out <: line[ x ];
			//printf( "-%4.1d ", line[ x ] ); //uncomment to show image values
		}

		//printf( "\n" ); //uncomment to show image values
	}

	_closeinpgm();
	printf( "DataInStream:Done...\n" );
	return;
}

int cur_line (int line_idx) {
	if (line_idx == 0)
		return LINES_STORED;
	else
		return line_idx - 1;
}

int prev_line (int line_idx) {
	int current_line = cur_line (line_idx);

	if (current_line == 0)
		return LINES_STORED;
	else
		return current_line - 1;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to farm out parts of the image...
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out, chanend c_workers[]) {
	uchar val;
	//uchar img[IMHT * IMWD];
	//uchar n[NEIGHBOURS];
	//int yoffset;
	//int xboundary, yboundary;
	int boundary;

	int line_idx = 0;
	int pixel_idx = 0;
	uchar line[LINES_STORED][IMWD];

	printf("ProcessImage:Start, size = %dx%d\n", IMHT, IMWD);

	// For every line in the image
	for (int y = 0; y < IMHT; y++) {
		//printf ("\n\nProcessImage:Line %d\n\n", y);

		// Retrieve each pixel in the line
		for (int x = 0; x < IMWD; x++) {
			c_in :> line[line_idx][x];
		}

		// FIRST LINE
		if (y == 0) {
			//printf ("ProcessImage:First line...\n");
			for (int i = 0; i < IMWD; i++)
				c_out <: (uchar)(BLACK);
			//printf ("ProcessImage:Done!\n");
		}

		// SUBSEQUENT LINES
		// This does nothing for second, as 3 lines need to be stored first
		if (y > 1) {
			pixel_idx = 0;
			while (pixel_idx != IMWD) {
				// Retrieve value from each worker
				// and send it to output
				if ( (y > 2) || ((y == 2) && (pixel_idx > 0)) ) {
					//printf ("ProcessImage:Retrieving results from workers\n");
					for (int i = 0; i < MAX_WORKERS; i++) {
						//printf ("ProcessImage:Waiting for worker %d...\n", i);
						c_workers[i] :> val;
						//printf ("ProcessImage:Done!\n");
						c_out <: (uchar)(val);
					}
				}

				// Give each worker a new pixel
				for (int i = 0; i < MAX_WORKERS; i++) {
					// Are we on a boundary?
					if (pixel_idx == 0 || pixel_idx == (IMWD - 1)) {
						//printf ("ProcessImage:Boundary pixel\n");
						boundary = 1;
					}

					//printf ("ProcessImage:Sending to worker %d...\n", i);

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

					//printf ("ProcessImage:Done\n");

					// Increment pixel index
					pixel_idx++;
				}
			}
		}

		// LAST LINE
		if (y == IMHT-1) {
			//printf("ProcessImage:Last line...\n");
			for (int i = 0; i < MAX_WORKERS; i++) {
				c_workers[i] :> val;
				c_out <: (uchar)(val);

				// Shutdown the worker threads
				c_workers[i] <: SHUTDOWN;
			}

			for (int i = 0; i < IMWD; i++)
				c_out <: (uchar)(BLACK);

			//printf ("ProcessImage:Done\n");
		}

		// Increment the line index, in a circular manner
		line_idx = (line_idx + 1) % LINES_STORED;
	}

	printf("ProcessImage:Shutting down...\n");
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Worker thread
//
/////////////////////////////////////////////////////////////////////////////////////////
void worker(chanend c_dist) {
	uchar val;
	uchar blurred;
	int boundary;
	int running = 1;

	while (running) {
		// Receive boundary flag
		c_dist :> boundary;

		// Shutdown received?
		if (boundary == SHUTDOWN) {
			//printf ("Worker:Received shutdown request.\n");
			running = 0;
			break;
		}

		// Initialise blurred with black
		blurred = BLACK;

		//printf ("Worker:Computing value\n");

		if (!boundary) {
			for (int i = 0; i < NEIGHBOURS; i++) {
				c_dist :> val;
				blurred += val;
			}

			blurred = blurred / NEIGHBOURS;
		}

		//printf ("Worker:Writing value (%d) to channel\n", blurred);

		// Return blurred value
		c_dist <: blurred;
	}

	printf ("Worker:Shutting down...\n");
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to pgm image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in) {
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
			c_in :> line[x];
			//printf( "+%4.1d ", line[x] );
			}

		//printf( "\n" );
		_writeoutline( line, IMWD );
	}

	_closeoutpgm();
	printf( "DataOutStream:Done...\n" );
	return;
}

//MAIN PROCESS defining channels, orchestrating and starting the threads
int main() {
	chan c_inIO, c_outIO; //extend your channel definitions here
	chan c_workers[MAX_WORKERS];

	// TODO - extend/change this par statement to implement your concurrent filter
	par {
		on stdcore[0]: DataInStream(INFNAME, c_inIO);
		on stdcore[1]: distributor(c_inIO, c_outIO, c_workers);
		on stdcore[2]: DataOutStream(OUTFNAME, c_outIO);

		// Replication of workers
		par (int k=0;k<MAX_WORKERS;k++) {
			on stdcore[k%4]: worker(c_workers[k]);
		}
	}

	// Return success
	return 0;
}
