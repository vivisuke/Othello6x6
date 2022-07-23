//----------------------------------------------------------------------
//
//			File:			"BoardArray.h"
//			Created:		23-7-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#pragma once

#include <vector>

typedef unsigned char uchar;

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

class BoardArray {
public:
	BoardArray();
public:
	void	init();
	void	print();
	bool	can_put_BLACK(int x, int y);
	bool	can_put_sub_BLACK(int ix, int dir);
	bool	can_put_WHITE(int x, int y);
	bool	can_put_sub_WHITE(int ix, int dir);
	int		put_BLACK(int x, int y);
	int		put_sub_BLACK(int ix, int dir);
	int		put_WHITE(int x, int y);
	int		put_sub_WHITE(int ix, int dir);
	void	un_put_BLACK();
	void	un_put_WHITE();
protected:

private:
	uchar	m_bd[ARY_SIZE];
	std::vector<uchar>		m_stack;	//	put(), un_put() 用スタック
};
