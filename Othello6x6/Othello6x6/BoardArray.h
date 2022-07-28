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
#include "Othello6x6.h"


class BoardArray {
public:
	BoardArray();
public:
	void	init();
	void	print();
	int		toIndex(int x, int y, int dir) { return toIndex(xyToIndex(x, y), dir); }
	int		toIndex(int ix, int dir);
	bool	can_put_BLACK(int x, int y);
	bool	can_put_BLACK(int ix);
	bool	can_put_sub_BLACK(int ix, int dir);
	bool	can_put_WHITE(int x, int y);
	bool	can_put_WHITE(int ix);
	bool	can_put_sub_WHITE(int ix, int dir);
	int		put_BLACK(int ix);
	int		put_WHITE(int ix);
	int		put_BLACK(int x, int y);
	int		put_WHITE(int x, int y);
	int		put_sub_BLACK(int ix, int dir);
	int		put_sub_WHITE(int ix, int dir);
	void	un_put_BLACK();
	void	un_put_WHITE();
protected:

private:
	uchar	m_bd[ARY_SIZE];
	std::vector<uchar>		m_stack;	//	put(), un_put() 用スタック
};
