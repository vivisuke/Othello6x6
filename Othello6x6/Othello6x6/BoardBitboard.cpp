//----------------------------------------------------------------------
//
//			File:			"BoardBitboard.cpp"
//			Created:		25-7-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#include <iostream>
#include "BoardBitboard.h"

using namespace std;

void BoardBitboard::init() {
	//cout << ("0x10" << 1) << "\n";
	//cout << ("0x10" << -1) << "\n";
	m_black = C4_BIT | D3_BIT;
	m_white = C3_BIT | D4_BIT;
}
static const char *dig_str[] = {"１", "２", "３", "４", "５", "６"};
void print(Bitboard black, Bitboard white) {
	cout << "＼ａｂｃｄｅｆ\n";
	for(int y = 0; y != N_VERT; ++y) {
		cout << dig_str[y];
		for(int x = 0; x != N_HORZ; ++x) {
			auto bit = xyToBit(x, y);
			if( (black & bit) != 0 ) cout << "Ｘ";
			else if( (white & bit) != 0 ) cout << "○";
			else cout << "・";
		}
		cout << "\n";
	}
   	cout << "\n";
}
void BoardBitboard::print() const {
	::print(m_black, m_white);
}
//	空欄の bit 位置に黒を打った場合に、返る白石ビットを返す
Bitboard get_revbits(Bitboard black, Bitboard white, Bitboard bit) {
	return	get_revbits_dir(black, white, bit, DIR_UL) | get_revbits_dir(black, white, bit, DIR_U) | get_revbits_dir(black, white, bit, DIR_UR) | 
			get_revbits_dir(black, white, bit, DIR_L) | get_revbits_dir(black, white, bit, DIR_R) | 
			get_revbits_dir(black, white, bit, DIR_DL) | get_revbits_dir(black, white, bit, DIR_D) | get_revbits_dir(black, white, bit, DIR_DR);
}
Bitboard get_revbits_dir(Bitboard black, Bitboard white, Bitboard bit, int dir) {
	Bitboard b = 0;
	if( dir > 0 ) {
		if( (white & (bit <<= dir)) == 0 ) return 0;	//	白でない
		do {
			b |= bit;
		} while( (white & (bit <<= dir)) != 0 );		//	白が続く間ループ
	} else {
		dir = -dir;
		if( (white & (bit >>= dir)) == 0 ) return 0;	//	白でない
		do {
			b |= bit;
		} while( (white & (bit >>= dir)) != 0 );		//	白が続く間ループ
	}
	if( (black & bit) != 0 ) return b;
	return 0;
}
//	bit 位置に黒を打った場合に、返る白石ビットを返す
Bitboard BoardBitboard::get_revbits(Bitboard bit) const {
	return ::get_revbits(m_black, m_white, bit);
	//return	get_revbits_dir(bit, DIR_UL) | get_revbits_dir(bit, DIR_U) | get_revbits_dir(bit, DIR_UR) | 
	//		get_revbits_dir(bit, DIR_L) | get_revbits_dir(bit, DIR_R) | 
	//		get_revbits_dir(bit, DIR_DL) | get_revbits_dir(bit, DIR_D) | get_revbits_dir(bit, DIR_DR);
}
#if	0
Bitboard BoardBitboard::get_revbits_dir(Bitboard bit, int dir) const {
	Bitboard b = 0;
	if( dir > 0 ) {
		if( (m_white & (bit <<= dir)) == 0 ) return 0;	//	白でない
		do {
			b |= bit;
		} while( (m_white & (bit <<= dir)) != 0 );		//	白が続く間ループ
	} else {
		dir = -dir;
		if( (m_white & (bit >>= dir)) == 0 ) return 0;	//	白でない
		do {
			b |= bit;
		} while( (m_white & (bit >>= dir)) != 0 );		//	白が続く間ループ
	}
	if( (m_black & bit) != 0 ) return b;
	return 0;
}
#endif
