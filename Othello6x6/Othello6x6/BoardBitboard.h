//----------------------------------------------------------------------
//
//			File:			"BoardBitboard.h"
//			Created:		25-7-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#pragma once

#include "Othello6x6.h"

#define		BB_MASK		0x3f3f3f3f3f3f

#define		C3_BIT		(0x08<<(8*3))
#define		C4_BIT		(0x08<<(8*2))
#define		D3_BIT		(0x04<<(8*3))
#define		D4_BIT		(0x04<<(8*2))

typedef unsigned _int64	Bitboard;

inline Bitboard xyToBit(int x, int y) {		//	x: [0, N_HORZ), y: [0, N_VERT)
	return (Bitboard)1<< ((N_VERT-1-y)*8 + (N_HORZ-1-x));
}

class BoardBitboard {
public:
	BoardBitboard() { init(); }
public:
	void	init();
	void	print() const;
private:
	Bitboard	m_black;
	Bitboard	m_white;
};
