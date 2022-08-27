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

	N_PAT = 3*3*3*3*3*3,

	EMPTY = 0,
	BLACK,
	WHITE,
	WALL,			//	番人

	//	パターンタイプ
	PTYPE_LINE1 = 0,	//	1・6行目、1・6列目
	PTYPE_LINE2,
	PTYPE_LINE3,
	PTYPE_DIAG6,		//	中央対角線上
	PTYPE_DIAG5,		//	
	PTYPE_DIAG4,		//	
	PTYPE_DIAG3,		//	
	N_PTYPE,
};
inline int xyToIndex(int x, int y) {		//	x: [1, N_HORZ], y: [1, N_VERT]
	return y * ARY_WIDTH + x;
}
