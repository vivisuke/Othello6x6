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

#define		DIR_UL		9
#define		DIR_U		8
#define		DIR_UR		7
#define		DIR_L		1
#define		DIR_R		(-1)
#define		DIR_DL		(-7)
#define		DIR_D		(-8)
#define		DIR_DR		(-9)

typedef unsigned _int64	Bitboard;

inline Bitboard xyToBit(int x, int y) {		//	x: [0, N_HORZ), y: [0, N_VERT)
	return (Bitboard)1<< ((N_VERT-1-y)*8 + (N_HORZ-1-x));
}
void print(Bitboard black, Bitboard white);
Bitboard get_revbits(Bitboard black, Bitboard white, Bitboard bit);	//	bit 位置に黒を打った場合に、返る白石ビットを返す
Bitboard get_revbits_dir(Bitboard black, Bitboard white, Bitboard bit, int dir);		//	

class BoardBitboard {
public:
	BoardBitboard() { init(); }
public:
	void	init();
	void	print() const;
	Bitboard	get_revbits(Bitboard bit) const;	//	bit 位置に黒を打った場合に、返る白石ビットを返す
	Bitboard	get_revbits_dir(Bitboard bit, int dir) const;		//	
public:
	Bitboard	m_black;
	Bitboard	m_white;
};
