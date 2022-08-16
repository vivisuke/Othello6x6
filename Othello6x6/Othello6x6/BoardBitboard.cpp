//----------------------------------------------------------------------
//
//			File:			"BoardBitboard.cpp"
//			Created:		25-7-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#include <iostream>
#include <bit>
#include <cstdint>
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
	auto bc = popcount(black);
	auto wc = popcount(white);
	cout << "Ｘ：" << bc << " ○：" << wc << " ・：" << (N_HORZ*N_VERT - bc - wc) << "\n";
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
#if	0
	if( dir > 0 ) {
		if( (white & (bit <<= dir)) == 0 ) return 0;	//	白でない
		if( (white & (bit <<= dir)) == 0 ) {	//	白でない
			if( (black & 
		}
#else
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
#endif
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

void BoardBitboard::put_black(Bitboard bit) {
	auto rev = get_revbits(bit);
	if( rev != 0 ) {
		m_black |= rev | bit;
		m_white ^= rev;
	}
}
int popcount(Bitboard bits) {
	bits = (bits & 0x555555555555) + ((bits >> 1) & 0x555555555555);    //  2bitごとに計算
    bits = (bits & 0x333333333333) + ((bits >> 2) & 0x333333333333);    //  4bitごとに計算
    bits = (bits & 0x0f0f0f0f0f0f) + ((bits >> 4) & 0x0f0f0f0f0f0f);    //  8bitごとに計算
    bits = (bits & 0x00ff00ff00ff) + ((bits >> 8) & 0x00ff00ff00ff);    //  16bitごとに計算
    bits = (bits & 0xffff0000ffff) + ((bits >> 16) & 0xffff0000ffff);    //  32bitごとに計算
    bits = (bits & 0x0000ffffffff) + ((bits >> 32) & 0x0000ffffffff);    //  64bitごとに計算
    return (int)bits;
	//auto i = static_cast<std::uint64_t>(bb);
	//return std::popcount(i);
}
