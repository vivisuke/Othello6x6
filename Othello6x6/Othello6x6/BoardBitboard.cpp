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
#include <assert.h>
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

void put_black(Bitboard &black, Bitboard &white, Bitboard bit) {
	auto rev = get_revbits(black, white, bit);
	if( rev != 0 ) {
		black |= rev | bit;
		white ^= rev;
	}
}
void BoardBitboard::put_black(Bitboard bit) {
	::put_black(m_black, m_white, bit);
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
int negaAlpha(Bitboard black, Bitboard white, int alpha, int beta, bool passed = false) {
	Bitboard spc = ~(black | white) & BB_MASK;		//	空欄箇所
	if( spc == 0 ) {	//	空欄無しの場合
		//print(black, white);
		return popcount(black) - popcount(white);
	}
	bool put = false;		//	着手箇所あり
	//	８近傍が白の場所のみ取り出す
	spc &= (white<<DIR_UL) | (white<<DIR_U) | (white<<DIR_UR) | (white<<DIR_L) | 
			(white>>DIR_UL) | (white>>DIR_U) | (white>>DIR_UR) | (white>>DIR_L);
	while( spc != 0 ) {
		Bitboard b = -(_int64)spc & spc;		//	最右ビットを取り出す
		auto rev = get_revbits(black, white, b);
		if( rev != 0 ) {
			put = true;
			auto ev = -negaAlpha(white ^ rev, black | rev | b, -beta, -alpha);
			if( ev >= beta ) return ev;		//	ベータカット
			alpha = std::max(alpha, ev);
		}
		spc ^= b;		//	最右ビット消去
	}
	if( !put ) {		//	パスの場合
		if( !passed ) {		//	１手前がパスでない
			return -negaAlpha(white, black, -beta, -alpha, true);
		} else {			//	１手前がパス → 双方パスで終局
			//print(black, white);
			//	done: 空欄は勝者のものとしてカウント
			int bc = popcount(black);
			int wc = popcount(white);
			alpha = bc - wc;
			spc = ~(black | white) & BB_MASK;		//	空欄箇所
			if( spc != 0 ) {	//	空欄ありの場合
				if( bc > wc ) alpha += popcount(spc);
				else if( bc < wc ) alpha -= popcount(spc);
			}
			//return alpha;
			//return popcount(black) - popcount(white);
		}
	}
	return alpha;
}
//	（黒番）終盤完全読み
//	双方着手不可能な場合は、alpha: -INT_MAX, return: 0 を返す
Bitboard negaAlpha(Bitboard black, Bitboard white, int &alpha) {
	Bitboard spc = ~(black | white) & BB_MASK;		//	空欄箇所
	if( spc == 0 ) {	//	空欄無しの場合
		alpha = popcount(black) - popcount(white);
		return 0;
	}
	Bitboard mxpos = 0;	//	評価値最大着手箇所
	alpha = -INT_MAX;
	const int beta = INT_MAX;
	//	８近傍が白の場所のみ取り出す
	spc &= (white<<DIR_UL) | (white<<DIR_U) | (white<<DIR_UR) | (white<<DIR_L) | 
			(white>>DIR_UL) | (white>>DIR_U) | (white>>DIR_UR) | (white>>DIR_L);
	while( spc != 0 ) {
		Bitboard b = -(_int64)spc & spc;		//	最右ビットを取り出す
		auto rev = get_revbits(black, white, b);
		if( rev != 0 ) {
			auto ev = -negaAlpha(white ^ rev, black | rev | b, -beta, -alpha);
			if( ev > alpha ) {
				alpha = ev;
				mxpos = b;
			}
		}
		spc ^= b;		//	最右ビット消去
	}
	if( mxpos == 0 ) {		//	黒着手不可の場合
		int bc = popcount(black);
		int wc = popcount(white);
		alpha = bc - wc;
		spc = ~(black | white) & BB_MASK;		//	空欄箇所
		if( spc != 0 ) {	//	空欄ありの場合
			if( bc > wc ) alpha += popcount(spc);
			else if( bc < wc ) alpha -= popcount(spc);
		}
	}
	return mxpos;
}
int bitToX(Bitboard b) {		//	x: [0, N_HORZ), y: [0, N_VERT)
	if( b != 0 ) {
		while( (b & 255) == 0 )
			b >>= 8;
		int mask = 1;
		for(int x = N_HORZ; --x >= 0; mask<<=1) {
			if( (b & mask) != 0 ) return x;
		}
	}
	assert(0);
	return -1;
}
int bitToY(Bitboard b) {		//	x: [0, N_HORZ), y: [0, N_VERT)
	for(int y = N_HORZ; --y >= 0; b>>=8) {
		if( (b & 255) != 0 ) return y;
	}
	assert(0);
	return -1;
}
//	pos:
//		横方向：左端指定
//		縦方向：上端指定
//		左上右下方向：左端上端指定
//		右上左下方向：右端上端指定
int get_pat_index(Bitboard black, Bitboard white, Bitboard pos, int dir, int len) {
	int index = 0;
	for(int i = 0; i != len; ++i) {
		index *= 3;
		index += (white&pos) != 0 ? 2 : (black&pos) != 0 ? 1 : 0;
		pos >>= dir;
	}
	return index;
}
int get_pat_index(Bitboard black, Bitboard white, Bitboard pos, int dir) {
	int index = 0;
	while( pos != 0 ) {
		index = index * 3 + ((white&pos) != 0 ? 2 : (black&pos) != 0 ? 1 : 0);
		pos  = (pos >> dir) & BB_MASK;
	}
	return index;
}
void get_pat_indexes(Bitboard black, Bitboard white, std::vector<int>& lst) {
	lst.clear();
	for(int y = 0; y != N_VERT; ++y) {
		int index = get_pat_index(black, white, xyToBit(0, y), DIR_L);
		lst.push_back(index);
		//cout << "  " << y << ": " << index << "\n";
	}
	//cout << "\nvertical:\n";
	for(int x = 0; x != N_HORZ; ++x) {
		int index = get_pat_index(black, white, xyToBit(x, 0), DIR_U);
		lst.push_back(index);
		//cout << "  " << x << ": " << index << "\n";
	}
	//cout << "\ndiagonal(／):\n";
	for(int x = 2; x != N_HORZ; ++x) {
		int index = get_pat_index(black, white, xyToBit(x, 0), DIR_UR);
		lst.push_back(index);
		//cout << "  " << x << ": " << index << "\n";
	}
	for(int y = 1; y != N_VERT-2; ++y) {
		int index = get_pat_index(black, white, xyToBit(N_HORZ-1, y), DIR_UR);
		lst.push_back(index);
		//cout << "  " << y << ": " << index << "\n";
	}
	//cout << "\ndiagonal(＼):\n";
	for(int x = N_HORZ-2; --x >= 0;) {
		int index = get_pat_index(black, white, xyToBit(x, 0), DIR_UL);
		lst.push_back(index);
		//cout << "  " << x << ": " << index << "\n";
	}
	for(int y = 1; y != N_VERT-2; ++y) {
		int index = get_pat_index(black, white, xyToBit(0, y), DIR_UL);
		lst.push_back(index);
		//cout << "  " << y << ": " << index << "\n";
	}
}
string bb_to_string(Bitboard bb) {
	const int len = 2*6;
	string str(len, ' ');
	for(int i = 0; i != len; ++i) {
		str[len-1-i] = "0123456789abcdef"[bb % 16];
		bb /= 16;
	}
	return str;
}
#if 0
//	空欄に隣接する部分をbbから削除
Bitboard remove_on_space(Bitboard bb, Bitboard spc) {
	return 0;
}
#endif
