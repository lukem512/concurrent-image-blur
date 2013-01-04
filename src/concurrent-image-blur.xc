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

/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to farm out parts of the image...
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out, chanend c_workers[]) {
	uchar val;
	uchar img[IMHT * IMWD];
	uchar n[NEIGHBOURS];
	int yoffset;
	int xboundary, yboundary;

	printf("ProcessImage:Start, size = %dx%d\n", IMHT, IMWD);

	// TODO - This code is to be replaced – it is a place holder for farming out the work...
	yoffset = 0;
	for (int y = 0; y < IMHT; y++) {
		if (y == 0 || y == (IMHT - 1)) {
			yboundary = 1;
		}

		for (int x = 0; x < IMWD; x++) {
			c_in :> img[yoffset + x];
		}

		// Increase y-offset
		yoffset += IMHT;
	}

	// TODO - this code needs replacing
	yoffset = 0;
	for (int y = 0; y < IMHT; y++) {
		if (y == 0 || y == (IMHT - 1)) {
			yboundary = 1;
		}

		for (int x = 0; x < IMWD; x++) {
			if (x == 0 || x == (IMWD - 1)) {
				xboundary = 1;
			}

			if (!yboundary && !xboundary) {
				// Previous row
				n[0] = img[yoffset - IMWD + x - 1];
				n[1] = img[yoffset - IMWD + x];
				n[2] = img[yoffset - IMWD + x + 1];

				// Current row
				n[3] = img[yoffset + x - 1];
				n[4] = img[yoffset + x];
				n[5] = img[yoffset + x + 1];

				// Next row
				n[6] = img[yoffset + IMWD + x - 1];
				n[7] = img[yoffset + IMWD + x];
				n[8] = img[yoffset + IMWD + x + 1];
			}

			//printf ("Blurring pixel (%d, %d)\n", y, x);
			val = blur(n, (xboundary | yboundary));
			//printf ("Got %d\n", val);

			//Need to cast
			c_out <: (uchar)(val);

			// Reset boundary flag for next col
			xboundary = 0;
		}

		// Reset boundary flag for next row
		yboundary = 0;

		// Increase y-offset
		yoffset += IMHT;
	}

	printf("ProcessImage:Done...\n");
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Worker thread
//
/////////////////////////////////////////////////////////////////////////////////////////
void worker(chanend c_dist) {
	uchar val;
	int boundary;

	c_dist :> val;

	// TODO

	c_dist <: val;
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
