//----------------------------------------------------------------------
//
//			File:			"BoardBitboard.h"
//			Created:		25-7-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#pragma once

#include <string>
#include <vector>
#include "Othello6x6.h"

/*
	Bitboard:

	＼ ａ ｂ ｃ ｄ ｅ ｆ →X
	１ 20 10 08 04 02 01	<< 40
	２ 20 10 08 04 02 01	<< 32
	３ 20 10 08 04 02 01	<< 24
	４ 20 10 08 04 02 01	<< 16
	５ 20 10 08 04 02 01	<< 8
	６ 20 10 08 04 02 01	
	↓Y
*/

#define		BB_MASK		0x3f3f3f3f3f3f

#define		C3_BIT		(0x08<<(8*3))
#define		C4_BIT		(0x08<<(8*2))
#define		D3_BIT		(0x04<<(8*3))
#define		D4_BIT		(0x04<<(8*2))
#define		E4_BIT		(0x02<<(8*2))

#define		DIR_UL		9
#define		DIR_U		8
#define		DIR_UR		7
#define		DIR_L		1
#define		DIR_R		(-1)
#define		DIR_DL		(-7)
#define		DIR_D		(-8)
#define		DIR_DR		(-9)

typedef unsigned char uchar;
typedef unsigned _int64	Bitboard;

inline Bitboard xyToBit(int x, int y) {		//	x: [0, N_HORZ), y: [0, N_VERT)
	int nx = (N_HORZ-1-x);
	int ny = (N_VERT-1-y);
	int n = ny*8 + nx;
	return (Bitboard)1<< ((N_VERT-1-y)*8 + (N_HORZ-1-x));
}
int bitToX(Bitboard b);		//	x: [0, N_HORZ), y: [0, N_VERT)
int bitToY(Bitboard b);		//	x: [0, N_HORZ), y: [0, N_VERT)
void print(Bitboard black, Bitboard white);
bool can_put_black(Bitboard black, Bitboard white, Bitboard bit);
Bitboard get_revbits(Bitboard black, Bitboard white, Bitboard bit);	//	bit 位置に黒を打った場合に、返る白石ビットを返す
Bitboard get_revbits_dir(Bitboard black, Bitboard white, Bitboard bit, int dir);		//	
int popcount(Bitboard);
Bitboard negaAlpha(Bitboard black, Bitboard white, int &ev, bool=false);		//	終盤完全読み
void put_black(Bitboard &black, Bitboard &white, Bitboard bit);
int get_pat_index_shr(Bitboard black, Bitboard white, Bitboard pos, int dir, int len);
int get_pat_index_shl(Bitboard black, Bitboard white, Bitboard pos, int dir, int len);
int get_pat_index(Bitboard black, Bitboard white, Bitboard pos, int dir);
void get_pat_indexes(Bitboard black, Bitboard white, std::vector<int>& lst);
void get_corner9_indexes(Bitboard black, Bitboard white, std::vector<int>& lst);
void get_corner8_indexes_hv(Bitboard black, Bitboard white, std::vector<int>& lst);		//	角パターンインデックス計算、水平優先
void get_corner8_indexes_vh(Bitboard black, Bitboard white, std::vector<int>& lst);		//	角パターンインデックス計算、垂直優先
int num_place_can_put_black(Bitboard black, Bitboard white);		//	黒着手可能箇所数
std::string bb_to_string(Bitboard bb);
Bitboard remove_on_space(Bitboard bb, Bitboard spc);		//	空欄に隣接する部分をbbから削除
uchar get_color(Bitboard black, Bitboard white, Bitboard bit);
void scan_shr(Bitboard black, Bitboard white, Bitboard bit, int dir);	//	dir 方向にスキャン
Bitboard scan_cannot_turnover_shr(Bitboard black, Bitboard white, Bitboard bit, int dir);	//	dir 方向にスキャンし、ひっくり返らないビットを返す
void get_num_cannot_turnover(Bitboard black, Bitboard white, int &nb, int &nw);


class BoardBitboard {
public:
	BoardBitboard() { init(); }
public:
	void	init();
	void	print() const;
	Bitboard	get_revbits(Bitboard bit) const;	//	bit 位置に黒を打った場合に、返る白石ビットを返す
	//Bitboard	get_revbits_dir(Bitboard bit, int dir) const;		//	
	void	put_black(Bitboard bit);
public:
	Bitboard	m_black;
	Bitboard	m_white;
};
