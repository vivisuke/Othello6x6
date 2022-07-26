﻿//----------------------------------------------------------------------
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

static const char *dig_str[] = {"１", "２", "３", "４", "５", "６"};
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
	cout << "\n";
}
int BoardArray::toIndex(int ix, int dir) {
	int v = 0;
	while( m_bd[ix] != WALL ) {
		v = v * 3 + m_bd[ix];
		ix += dir;
	}
	return v;
}
bool BoardArray::can_put_sub_BLACK(int ix, int dir) {
	if( m_bd[ix+=dir] != WHITE ) return false;
	while( m_bd[ix+=dir] == WHITE ) {}
	return m_bd[ix] == BLACK;
}
bool BoardArray::can_put_sub_WHITE(int ix, int dir) {
	if( m_bd[ix+=dir] != BLACK ) return false;
	while( m_bd[ix+=dir] == BLACK ) {}
	return m_bd[ix] == WHITE;
}
bool BoardArray::can_put_BLACK(int x, int y) {
	return can_put_BLACK(xyToIndex(x, y));
}
bool BoardArray::can_put_BLACK(int ix) {
	if( m_bd[ix] != EMPTY ) return false;
	return	can_put_sub_BLACK(ix, -ARY_WIDTH-1) || can_put_sub_BLACK(ix, -ARY_WIDTH) || can_put_sub_BLACK(ix, -ARY_WIDTH+1) || 
			can_put_sub_BLACK(ix, -1) || can_put_sub_BLACK(ix, +1) || 
			can_put_sub_BLACK(ix, ARY_WIDTH-1) || can_put_sub_BLACK(ix, ARY_WIDTH) || can_put_sub_BLACK(ix, ARY_WIDTH+1);
}
bool BoardArray::can_put_WHITE(int x, int y) {
	return can_put_WHITE(xyToIndex(x, y));
}
bool BoardArray::can_put_WHITE(int ix) {
	if( m_bd[ix] != EMPTY ) return false;
	return	can_put_sub_WHITE(ix, -ARY_WIDTH-1) || can_put_sub_WHITE(ix, -ARY_WIDTH) || can_put_sub_WHITE(ix, -ARY_WIDTH+1) || 
			can_put_sub_WHITE(ix, -1) || can_put_sub_WHITE(ix, +1) || 
			can_put_sub_WHITE(ix, ARY_WIDTH-1) || can_put_sub_WHITE(ix, ARY_WIDTH) || can_put_sub_WHITE(ix, ARY_WIDTH+1);
}
int BoardArray::put_sub_BLACK(int ix, int dir) {	//	返した石数を返す
	if( m_bd[ix+=dir] != WHITE ) return 0;
	int ix0 = ix;
	int n = 1;
	while( m_bd[ix+=dir] == WHITE ) { ++n; }
	if( m_bd[ix] != BLACK ) return 0;
	do {
		m_bd[ix-=dir] = BLACK;
		m_stack.push_back((uchar)ix);
	} while( ix != ix0 );
	return n;
}
int BoardArray::put_sub_WHITE(int ix, int dir) {	//	返した石数を返す
	if( m_bd[ix+=dir] != BLACK ) return 0;
	int ix0 = ix;
	int n = 1;
	while( m_bd[ix+=dir] == BLACK ) { ++n; }
	if( m_bd[ix] != WHITE ) return 0;
	do {
		m_bd[ix-=dir] = WHITE;
		m_stack.push_back((uchar)ix);
	} while( ix != ix0 );
	return n;
}
int BoardArray::put_BLACK(int x, int y) {
	return put_BLACK(xyToIndex(x, y));
}
int BoardArray::put_BLACK(int ix) {
	if( m_bd[ix] != EMPTY ) return 0;
	int n = put_sub_BLACK(ix, -ARY_WIDTH-1) + put_sub_BLACK(ix, -ARY_WIDTH) + put_sub_BLACK(ix, -ARY_WIDTH+1) + 
			put_sub_BLACK(ix, -1) + put_sub_BLACK(ix, +1) + 
			put_sub_BLACK(ix, ARY_WIDTH-1) + put_sub_BLACK(ix, ARY_WIDTH) + put_sub_BLACK(ix, ARY_WIDTH+1);
	if( n != 0 ) {
		m_bd[ix] = BLACK;
		m_stack.push_back((uchar)ix);
		m_stack.push_back((uchar)n);
	}
	return n;
}
int BoardArray::put_WHITE(int x, int y) {
	return put_WHITE(xyToIndex(x, y));
}
int BoardArray::put_WHITE(int ix) {
	if( m_bd[ix] != EMPTY ) return 0;
	int n = put_sub_WHITE(ix, -ARY_WIDTH-1) + put_sub_WHITE(ix, -ARY_WIDTH) + put_sub_WHITE(ix, -ARY_WIDTH+1) + 
			put_sub_WHITE(ix, -1) + put_sub_WHITE(ix, +1) + 
			put_sub_WHITE(ix, ARY_WIDTH-1) + put_sub_WHITE(ix, ARY_WIDTH) + put_sub_WHITE(ix, ARY_WIDTH+1);
	if( n != 0 ) {
		m_bd[ix] = WHITE;
		m_stack.push_back((uchar)ix);
		m_stack.push_back((uchar)n);
	}
	return n;
}
void BoardArray::un_put_BLACK() {
	int n = m_stack.back();	m_stack.pop_back();
	m_bd[m_stack.back()] = EMPTY;	m_stack.pop_back();
	for(int i = 0; i != n; ++i) {
		m_bd[m_stack.back()] = WHITE;	m_stack.pop_back();
	}
}
void BoardArray::un_put_WHITE() {
	int n = m_stack.back();	m_stack.pop_back();
	m_bd[m_stack.back()] = EMPTY;	m_stack.pop_back();
	for(int i = 0; i != n; ++i) {
		m_bd[m_stack.back()] = BLACK;	m_stack.pop_back();
	}
}
