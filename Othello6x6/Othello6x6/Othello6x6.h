//----------------------------------------------------------------------
//
//			File:			"Othello6x6.h"
//			Created:		25-7-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#pragma once

typedef unsigned char uchar;
typedef unsigned short ushort;

enum {
	N_HORZ = 6,
	N_VERT = 6,
	ARY_WIDTH = N_HORZ + 1,
	ARY_SIZE = ARY_WIDTH*(N_VERT+2) + 1,

	EMPTY = 0,
	BLACK,
	WHITE,
	WALL,			//	番人
};
inline int xyToIndex(int x, int y) {		//	x: [1, N_HORZ], y: [1, N_VERT]
	return y * ARY_WIDTH + x;
}
