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

#define IMHT 16
#define IMWD 16
#define NEIGHBOURS 9
#define BLACK 0

/////////////////////////////////////////////////////////////////////////////////////////
//
// Method to blur a pixel given it's eight neighbouring pixels
//
/////////////////////////////////////////////////////////////////////////////////////////
uchar blur(uchar neighbours[NEIGHBOURS], int boundary) {
	uchar blurred;
	int intBlurred;

	if (boundary) {
		// Set to black if this is a boundary pixel
		blurred = BLACK;

		//printf ("Boundary detected, returning 0\n");
	} else {
		// Set to average of values
		for (int i = 0; i < NEIGHBOURS; i++)
			intBlurred += neighbours[i];

		blurred = intBlurred / NEIGHBOURS;

		//printf ("Returning blurred pixel of value %d (%d)\n", blurred);
	}

	return blurred;
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
void distributor(chanend c_in, chanend c_out) {
	uchar val;
	uchar img[IMHT * IMWD];
	uchar n[NEIGHBOURS];
	int yoffset;
	int xboundary, yboundary;

	printf("ProcessImage:Start, size = %dx%d\n", IMHT, IMWD);

	// TODO - This code is to be replaced – it is a place holder for farming out the work...
	for (int y = 0; y < IMHT; y++) {
		yoffset = y * IMHT;

		if (y == 0 || y == (IMHT - 1)) {
			yboundary = 1;
		}

		for (int x = 0; x < IMWD; x++) {
			c_in :> val;

			img[yoffset + x] = val;

			if (x == 0 || x == (IMWD - 1)) {
				xboundary = 1;
			}

			if (!yboundary && !xboundary) {
				n[0] = val;
				n[1] = img[yoffset + x - 1];
				n[2] = img[yoffset + x + 1];

				for (int i = -1; i < 2; i++)
					n[3 + i] = img[yoffset - IMHT + x - i];

				for (int i = -1; i < 2; i++)
					n[7 + i] = img[yoffset + IMHT + x - i];
			}

			val = blur(n, (xboundary | yboundary));

			//Need to cast
			c_out <: (uchar)(val);

			// Reset boundary flag for next col
			xboundary = 0;
		}

		// Reset boundary flag for next row
		yboundary = 0;
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
	char infname[] = "test/test0.pgm"; //put your input image path here
	char outfname[] = "test/testout.pgm"; //put your output image path here
	chan c_inIO, c_outIO; //extend your channel definitions here

	// TODO - extend/change this par statement to implement your concurrent filter
	par {
		DataInStream(infname, c_inIO);
		distributor(c_inIO, c_outIO);
		DataOutStream(outfname, c_outIO);
	}

	printf("Main:Done...\n");
	return 0;
}
