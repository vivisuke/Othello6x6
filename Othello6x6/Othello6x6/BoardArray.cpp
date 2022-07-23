//----------------------------------------------------------------------
//
//			File:			"BoardArray.cpp"
//			Created:		23-7-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#include <iostream>
#include "BoardArray.h"

using namespace std;

BoardArray::BoardArray() {
	init();
}

void BoardArray::init() {
	for(int i = 0; i != ARY_SIZE; ++i) m_bd[i] = WALL;
	for(int y = 1; y != N_VERT+1; ++y)
		for(int x = 1; x != N_HORZ+1; ++x)
			m_bd[xyToIndex(x, y)] = EMPTY;
	m_bd[xyToIndex(3, 3)] = WHITE;
	m_bd[xyToIndex(4, 4)] = WHITE;
	m_bd[xyToIndex(3, 4)] = BLACK;
	m_bd[xyToIndex(4, 3)] = BLACK;
}

const char *dig_str[] = {"１", "２", "３", "４", "５", "６"};
void BoardArray::print() {
	cout << "＼ａｂｃｄｅｆ\n";
	for(int y = 1; y != N_VERT+1; ++y) {
		cout << dig_str[y-1];
		for(int x = 1; x != N_HORZ+1; ++x) {
			switch( m_bd[xyToIndex(x, y)] ) {
			case EMPTY: cout << "・";	break;
			case BLACK: cout << "Ｘ";	break;
			case WHITE: cout << "○";	break;
			}
		}
		cout << "\n";
	}
}
bool can_put(int x, int y) {
}
