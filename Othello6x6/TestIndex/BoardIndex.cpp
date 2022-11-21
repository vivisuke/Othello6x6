#include <iostream>
#include "BoardIndex.h"

using namespace std;

using namespace std;

/*
＼ａｂｃｄｅｆ
１・・・・・・
２・・・・・・
３・・○Ｘ・・
４・・Ｘ○・・
５・・・・・・
６・・・・・・

※ Ｘ：黒、○：白

*/

//	状態遷移先インデックステーブル
short	g_put_black_ix[IX_TABLE_SIZE][N_HORZ];		//	黒を打った場合の遷移先インデックス
short	g_put_white_ix[IX_TABLE_SIZE][N_HORZ];		//	白を打った場合の遷移先インデックス

struct IndexTableItem {
	short	m_rev_black;		//	黒を打った場合に反転するビットs
	short	m_dstix_black;		//	黒を打った場合の遷移先インデックス
	short	m_rev_white;		//	白を打った場合に反転するビットs
	short	m_dstix_white;		//	白を打った場合の遷移先インデックス
};

IndexTableItem g_trans_table[IX_TABLE_SIZE][N_HORZ];	//	石を打った場合の反転ビット、遷移先インデックス

ushort patWToIndex(const std::vector<uchar> &lst) {
	ushort index = 0;
	for(int i = (int)lst.size() - 1; --i != 0;) {
		index = index * 3 + lst[i];
	}
	return index;
}
void indexToPatW(ushort index, std::vector<uchar> &lst, int len) {
	lst.resize(len+2);
	lst.front() = lst.back() = WALL;
	for(int i = 0; i != len; ++i) {
		lst[i+1] = index % 3;
		index /= 3;
	}
}
ushort patToIndex(const std::vector<uchar> &lst) {
	ushort index = 0;
	for(int i = (int)lst.size(); --i >= 0;) {
		index = index * 3 + lst[i];
	}
	return index;
}
void indexToPat(ushort index, std::vector<uchar> &lst, int len) {
	lst.resize(len);
	for(int i = 0; i != len; ++i) {
		lst[i] = index % 3;
		index /= 3;
	}
}
void indexToPat(ushort index, std::string &lst, int len) {
	lst.resize(len);
	for(int i = 0; i != len; ++i) {
		switch( index % 3 ) {
		case 0:	lst[i] = '.';	break;
		case 1:	lst[i] = 'X';	break;
		case 2:	lst[i] = 'O';	break;
		}
		index /= 3;
	}
}
void indexToPat(ushort index, uchar *ptr, int len) {
	for(int i = 0; i != len; ++i) {
		*ptr++ = index % 3;
		index /= 3;
	}
}
bool can_put_black(const std::vector<uchar> &pat, int i) {		//	パターンの i 番目位置（i:[0, 5]）に黒を打てるか？
	if( pat[i+1] != EMPTY ) return false;
	int k = i;
	if( pat[k] == WHITE ) {
		while( pat[--k] == WHITE ) {}
		if( pat[k] == BLACK ) return true;
	}
	k = i + 2;
	if( pat[k] == WHITE ) {
		while( pat[++k] == WHITE ) {}
		if( pat[k] == BLACK ) return true;
	}
	return false;
}
bool can_put_white(const std::vector<uchar> &pat, int i) {		//	パターンの i 番目位置（i:[0, 5]）に白を打てるか？
	if( pat[i+1] != EMPTY ) return false;
	int k = i;
	if( pat[k] == BLACK ) {
		while( pat[--k] == BLACK ) {}
		if( pat[k] == WHITE ) return true;
	}
	k = i + 2;
	if( pat[k] == BLACK ) {
		while( pat[++k] == BLACK ) {}
		if( pat[k] == WHITE ) return true;
	}
	return false;
}
//	パターンの i 番目位置（i:[0, N_HORZ)）に黒を打つ（patの内容を更新）
//	return: 返した石数を返す
int put_black_patW(std::vector<uchar> &pat, int i) {
	int n = 0;		//	返した石数
	if( pat[i+1] == EMPTY ) {
		int k = i;
		if( pat[k] == WHITE ) {
			while( pat[--k] == WHITE ) {}
			if( pat[k] == BLACK ) {
				do {
					pat[++k] = BLACK;
				} while( k != i + 1);
				n = i - k;
			}
		}
		k = i + 2;
		if( pat[k] == WHITE ) {
			while( pat[++k] == WHITE ) {}
			if( pat[k] == BLACK ) {
				do {
					pat[--k] = BLACK;
				} while( k != i + 1);
				n += k - (i + 1) - 1;
			}
		}
	}
	if( n != 0 ) {
		pat[i+1] = BLACK;
	}
	return n;
}
int put_white_patW(std::vector<uchar> &pat, int i) {
	int n = 0;		//	返した石数
	if( pat[i+1] == EMPTY ) {
		int k = i;
		if( pat[k] == BLACK ) {
			while( pat[--k] == BLACK ) {}
			if( pat[k] == WHITE ) {
				do {
					pat[++k] = WHITE;
				} while( k != i + 1);
				n = i - k;
			}
		}
		k = i + 2;
		if( pat[k] == BLACK ) {
			while( pat[++k] == BLACK ) {}
			if( pat[k] == WHITE ) {
				do {
					pat[--k] = WHITE;
				} while( k != i + 1);
				n += k - (i + 1) - 1;
			}
		}
	}
	if( n != 0 ) {
		pat[i+1] = WHITE;
	}
	return n;
}
//	パターンの i 番目位置（ i:[0, N_HORZ) ）に黒を打った場合に返る石bitsを返す
//	返る石パターン： b 番目 → 2^b
//	return: 返る石bitsを返す
short get_rev_bits_black(const std::vector<uchar> &pat, int i) {
	int rev = 0;		//	返える石パターン
	if( pat[i+1] == EMPTY ) {
		int b = 1 << i;
		int k = i;
		if( pat[k] == WHITE ) {
			int t = (b >>= 1);
			while( pat[--k] == WHITE ) {
				t |= (b >>= 1);
			}
			if( pat[k] == BLACK ) {
				rev |= t;
			}
		}
		b = 1 << i;
		k = i + 2;
		if( pat[k] == WHITE ) {
			int t = (b <<= 1);
			while( pat[++k] == WHITE ) {
				t |= (b <<= 1);
			}
			if( pat[k] == BLACK ) {
				rev |= t;
			}
		}
	}
	return rev;
}
short get_rev_bits_white(const std::vector<uchar> &pat, int i) {
	int rev = 0;		//	返る石パターン
	if( pat[i+1] == EMPTY ) {
		int b = 1 << i;
		int k = i;
		if( pat[k] == BLACK ) {
			int t = (b >>= 1);
			while( pat[--k] == BLACK ) {
				t |= (b >>= 1);
			}
			if( pat[k] == WHITE ) {
				rev |= t;
			}
		}
		b = 1 << i;
		k = i + 2;
		if( pat[k] == BLACK ) {
			int t = (b <<= 1);
			while( pat[++k] == BLACK ) {
				t |= (b <<= 1);
			}
			if( pat[k] == WHITE ) {
				rev |= t;
			}
		}
	}
	return rev;
}
//--------------------------------------------------------------------------------
uchar g_pat[] = {0, 0, 0, 0, 0, 0};
//uchar g_pat[] = {WALL, 0, 0, 0, 0, 0, 0, WALL};
int g_exp3[] = {1, 3, 3*3, 3*3*3, 3*3*3*3, 3*3*3*3*3};
//	index で指定されるパターンの i 番目位置（i:[0, 5]）に黒石を打った後のパターンインデックスを返す
//	引数（out）：	n1：マイナス方向に返る石数、n2：プラス方向に返る石数を返す
//	return: 石を打ったあとのパターンインデックス
ushort put_black(ushort index, int i, uchar& n1, uchar& n2) {
	int diff = 0;
	n1 = n2 = 0;		//	返した石数
	indexToPat(index, &g_pat[0]);
	if( g_pat[i] != EMPTY ) return 0;
	int k = i - 1;
	if( k >= 0 && g_pat[k] == WHITE ) {
		while( --k >= 0 && g_pat[k] == WHITE ) {}
		if( k >= 0 && g_pat[k] == BLACK ) {
			n1 = i - k - 1;
			do {
				diff += g_exp3[++k];
			} while( k != i - 1);
		}
	}
	k = i + 1;
	if( k != N_HORZ && g_pat[k] == WHITE ) {
		while( ++k != N_HORZ && g_pat[k] == WHITE ) {}
		if( k != N_HORZ && g_pat[k] == BLACK ) {
			n2 = k - i - 1;
			do {
				diff += g_exp3[--k];
			} while( k != i + 1);
		}
	}
	if( diff == 0 ) return 0;
	return index - diff + g_exp3[i]*BLACK;
}
ushort put_white(ushort index, int i, uchar& n1, uchar& n2) {
	int diff = 0;
	n1 = n2 = 0;		//	返した石数
	indexToPat(index, &g_pat[0]);
	if( g_pat[i] != EMPTY ) return 0;
	int k = i - 1;
	if( k >= 0 && g_pat[k] == BLACK ) {
		while( --k >= 0 && g_pat[k] == BLACK ) {}
		if( k >= 0 && g_pat[k] == WHITE ) {
			n1 = i - k - 1;
			do {
				diff += g_exp3[++k];
			} while( k != i - 1);
		}
	}
	k = i + 1;
	if( k != N_HORZ && g_pat[k] == BLACK ) {
		while( ++k != N_HORZ && g_pat[k] == BLACK ) {}
		if( k != N_HORZ && g_pat[k] == WHITE ) {
			n2 = k - i - 1;
			do {
				diff += g_exp3[--k];
			} while( k != i + 1);
		}
	}
	if( diff == 0 ) return 0;
	return index + diff + g_exp3[i]*WHITE;
}
void buildIndexTable() {
	bool verbose = false;
	vector<uchar> patW;			//	前後に壁ありパターン
	for(int ix = 0; ix != IX_TABLE_SIZE; ++ix) {		//	全インデックスについて
		//if( ix == 15 )
		//	cout << "x == 15\n";
		indexToPatW((short)ix, patW);
		if(verbose) cout << ix << ": " << patWtoString(patW) << " ";
		for(int k = 0; k != N_HORZ; ++k) {			//	各位置に黒石を打つ
			auto rev = get_rev_bits_black(patW, k);
			auto patW2 = patW;
			if( rev != 0 )
				put_black_patW(patW2, k);
			else
				patW2[k+1] = BLACK;
			auto ix2 = patWToIndex(patW2);
			if(verbose) cout << "0x" << std::hex << rev << std::dec << " " << ix2 << " ";
			g_trans_table[ix][k].m_rev_black = rev;
			g_trans_table[ix][k].m_dstix_black = ix2;
		}
		if(verbose) cout << "\n";
	}
	if(verbose) cout << "\n";
	verbose = false;
	for(int ix = 0; ix != IX_TABLE_SIZE; ++ix) {		//	全インデックスについて
		//if( ix == 15 )
		//	cout << "x == 15\n";
		indexToPatW((short)ix, patW);
		if(verbose) cout << ix << ": " << patWtoString(patW) << " ";
		for(int k = 0; k != N_HORZ; ++k) {			//	各位置に白石を打つ
			auto rev = get_rev_bits_white(patW, k);
			auto patW2 = patW;
			if( rev != 0 )
				put_white_patW(patW2, k);
			else
				patW2[k+1] = WHITE;
			auto ix2 = patWToIndex(patW2);
			if(verbose) cout << "0x" << std::hex << rev << std::dec << " " << ix2 << " ";
			g_trans_table[ix][k].m_rev_white = rev;
			g_trans_table[ix][k].m_dstix_white = ix2;
		}
		if(verbose) cout << "\n";
	}
	if(verbose) cout << "\n";
}
string patWtoString(std::vector<uchar> &patW) {
	string txt;
	for(int i = 1; i != patW.size() - 1; ++i) {
		switch( patW[i] ) {
		case EMPTY: txt += "・";	break;
		case BLACK: txt += "●";	break;
		case WHITE: txt += "○";	break;
		}
	}
	return txt;
}
//--------------------------------------------------------------------------------
void BoardIndex::init() {
	for(int i = 0; i != N_IX_HORZ; ++i) m_ix_horz[i] = 0;		//	全セル空欄
	for(int i = 0; i != N_IX_VERT; ++i) m_ix_vert[i] = 0;		//	全セル空欄
	for(int i = 0; i != N_IX_BL_UR; ++i) m_ix_bl_ur[i] = 0;		//	全セル空欄
	for(int i = 0; i != N_IX_UL_BR; ++i) m_ix_ul_br[i] = 0;		//	全セル空欄
	//
#if N_HORZ == 4
	m_ix_horz[1] = patToIndex({0, WHITE, BLACK, 0});
	m_ix_horz[2] = patToIndex({0, BLACK, WHITE, 0});
	m_ix_vert[1] = patToIndex({0, WHITE, BLACK, 0});
	m_ix_vert[2] = patToIndex({0, BLACK, WHITE, 0});
	m_ix_bl_ur[0] = patToIndex({0, BLACK, 0});
	m_ix_bl_ur[1] = patToIndex({0, WHITE, WHITE, 0});
	m_ix_bl_ur[2] = patToIndex({0, BLACK, 0});
	m_ix_ul_br[0] = patToIndex({0, WHITE, 0});
	m_ix_ul_br[1] = patToIndex({0, BLACK, BLACK, 0});
	m_ix_ul_br[2] = patToIndex({0, WHITE, 0});
#else
	m_ix_horz[2] = patToIndex({0, 0, WHITE, BLACK, 0, 0});
	m_ix_horz[3] = patToIndex({0, 0, BLACK, WHITE, 0, 0});
	m_ix_vert[2] = patToIndex({0, 0, WHITE, BLACK, 0, 0});
	m_ix_vert[3] = patToIndex({0, 0, BLACK, WHITE, 0, 0});
	m_ix_bl_ur[2] = patToIndex({0, 0, BLACK, 0, 0});
	m_ix_bl_ur[3] = patToIndex({0, 0, WHITE, WHITE, 0, 0});
	m_ix_bl_ur[4] = patToIndex({0, 0, BLACK, 0, 0});
	m_ix_ul_br[2] = patToIndex({0, 0, WHITE, 0, 0});
	m_ix_ul_br[3] = patToIndex({0, 0, BLACK, BLACK, 0, 0});
	m_ix_ul_br[4] = patToIndex({0, 0, WHITE, 0, 0});
#endif
}

static const char *dig_str[] = {"１", "２", "３", "４", "５", "６"};
void BoardIndex::print() const {
	vector<uchar> lst;
#if N_HORZ == 4
	cout << "＼ａｂｃｄ\n";
#else
	cout << "＼ａｂｃｄｅｆ\n";
#endif
	for(int y = 0; y != N_VERT; ++y) {
		cout << dig_str[y];
		indexToPat(m_ix_horz[y], lst);
		for(int x = 0; x != N_HORZ; ++x) {
			switch( lst[x] ) {
			case EMPTY: cout << "・";	break;
			case BLACK: cout << "Ｘ";	break;
			case WHITE: cout << "○";	break;
			}
		}
		cout << "\n";
	}
	cout << "\n";
}
void BoardIndex::print_vert() const {
	vector<uchar> lst;
	vector<uchar> s(N_HORZ*N_VERT, EMPTY);
	for(int x = 0; x != N_HORZ; ++x) {
		indexToPat(m_ix_vert[x], lst);
		for(int y = 0; y != N_VERT; ++y) {
			s[y*N_HORZ + x] = lst[y];
		}
	}
#if N_HORZ == 4
	cout << "＼ａｂｃｄ\n";
#else
	cout << "＼ａｂｃｄｅｆ\n";
#endif
	for(int y = 0; y != N_VERT; ++y) {
		cout << dig_str[y];
		for(int x = 0; x != N_HORZ; ++x) {
			switch( s[y*N_HORZ + x] ) {
			case EMPTY: cout << "・";	break;
			case BLACK: cout << "Ｘ";	break;
			case WHITE: cout << "○";	break;
			}
		}
		cout << "\n";
	}
	cout << "\n";
}
void BoardIndex::print_diagonal() const {		//	斜めインデックス表示
	vector<uchar> lst;
	vector<uchar> s(N_HORZ*N_VERT, EMPTY);
	for(int x = 0; x != N_IX_BL_UR; ++x) {
		indexToPat(m_ix_bl_ur[x], lst);
		for(int y = 0; y != N_VERT; ++y) {
			s[y*N_HORZ + x] = lst[y];
		}
	}
#if N_HORZ == 4
	cout << "＼ａｂｃｄ\n";
#else
	cout << "＼ａｂｃｄｅｆ\n";
#endif
	for(int y = 0; y != N_VERT; ++y) {
		cout << dig_str[y];
		for(int x = 0; x != N_HORZ; ++x) {
			switch( s[y*N_HORZ + x] ) {
			case EMPTY: cout << "・";	break;
			case BLACK: cout << "Ｘ";	break;
			case WHITE: cout << "○";	break;
			default:	cout << "？";	break;
			}
		}
		cout << "\n";
	}
	cout << "\n";
}
bool BoardIndex::can_put_black(int x, int y) const {
	return	g_trans_table[m_ix_horz[y]][x].m_rev_black != 0 ||
			g_trans_table[m_ix_vert[x]][y].m_rev_black != 0;
	//	undone: 斜めに返る場合対応
}
bool BoardIndex::can_put_white(int x, int y) const {
	return	g_trans_table[m_ix_horz[y]][x].m_rev_white != 0 ||
			g_trans_table[m_ix_vert[x]][y].m_rev_white != 0;
	//	undone: 斜めに返る場合対応
}
void BoardIndex::put_black(int x, int y) {
	const auto &h = g_trans_table[m_ix_horz[y]][x];
	auto hr = h.m_rev_black;			//	反転ビットs
	m_ix_horz[y] = h.m_dstix_black;		//	遷移先インデックス
	const auto &v = g_trans_table[m_ix_vert[x]][y];
	auto vr = v.m_rev_black;			//	反転ビットs
	m_ix_vert[x] = v.m_dstix_black;		//	遷移先インデックス
	//	反転された石によるインデックス更新
	if( hr != 0 ) {
		int mask = 1;
		for(int k = 0; k != N_HORZ; ++k, mask<<=1) {
			if( (hr & mask) != 0 )
				m_ix_vert[k] = g_trans_table[m_ix_vert[k]][y].m_dstix_black;
		}
	}
	if( vr != 0 ) {
		int mask = 1;
		for(int k = 0; k != N_VERT; ++k, mask<<=1) {
			if( (vr & mask) != 0 )
				m_ix_horz[k] = g_trans_table[m_ix_horz[k]][x].m_dstix_black;
		}
	}
}
void BoardIndex::put_white(int x, int y) {
	const auto &h = g_trans_table[m_ix_horz[y]][x];
	auto hr = h.m_rev_white;			//	反転ビットs
	m_ix_horz[y] = h.m_dstix_white;		//	遷移先インデックス
	const auto &v = g_trans_table[m_ix_vert[x]][y];
	auto vr = v.m_rev_white;			//	反転ビットs
	m_ix_vert[x] = v.m_dstix_white;		//	遷移先インデックス
	//	反転された石によるインデックス更新
	if( hr != 0 ) {
		int mask = 1;
		for(int k = 0; k != N_HORZ; ++k, mask<<=1) {
			if( (hr & mask) != 0 )
				m_ix_vert[k] = g_trans_table[m_ix_vert[k]][y].m_dstix_white;
		}
	}
	if( vr != 0 ) {
		int mask = 1;
		for(int k = 0; k != N_VERT; ++k, mask<<=1) {
			if( (vr & mask) != 0 )
				m_ix_horz[k] = g_trans_table[m_ix_horz[k]][x].m_dstix_white;
		}
	}
}
//
