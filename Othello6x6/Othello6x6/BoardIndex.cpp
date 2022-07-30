//----------------------------------------------------------------------
//
//			File:			"BoardIndex.cpp"
//			Created:		28-7-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#include <iostream>
#include "BoardIndex.h"

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

ushort patToIndex(const std::vector<uchar> &lst) {
	ushort index = 0;
	for(int i = lst.size(); --i >= 0;) {
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
//	パターンの i 番目位置（i:[0, 5]）に黒を打つ（patの内容を更新）
//	return: 返した石数を返す
int put_black(std::vector<uchar> &pat, int i) {
	if( pat[i+1] != EMPTY ) return 0;
	int n = 0;		//	返した石数
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
			n += k - (i + 1) - 1;
		}
	}
	return n;
}
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
//--------------------------------------------------------------------------------
struct SIndexTableItem {
public:
	SIndexTableItem(ushort dst_ix = 0, uchar n1 = 0, uchar n2 = 0)
		: m_dst_ix(dst_ix)
		, m_n1(n1)
		, m_n2(n2)
	{
	}
public:
	ushort		m_dst_ix;		//	遷移先インデックス
	uchar		m_n1;			//	x or y マイナス方向に返る石数
	uchar		m_n2;			//	x or y プラス方向に返る石数
};

//vector<SIndexTableItem[6]> g_indexTableBlack;
//vector<SIndexTableItem[6]> g_indexTableWhite;
SIndexTableItem g_indexTableBlack[IX_TABLE_SIZE*N_HORZ];
SIndexTableItem g_indexTableWhite[IX_TABLE_SIZE*N_HORZ];

void buildIndexTable() {
	//g_indexTableBlack.resize(IX_TABLE_SIZE);
	//g_indexTableWhite.resize(IX_TABLE_SIZE);
	//vector<uchar> pat(N_HORZ+2, WALL);		//	+2 for 番人
	for(int ix = 0; ix != IX_TABLE_SIZE; ++ix) {
#if	1
		for(int i = 0; i != N_HORZ; ++i) {
			uchar n1, n2;
			auto ix2 = put_black(ix, i, n1, n2);
			g_indexTableBlack[ix*N_HORZ + i] = SIndexTableItem(ix2, n1, n2);
			ix2 = put_white(ix, i, n1, n2);
			g_indexTableWhite[ix*N_HORZ + i] = SIndexTableItem(ix2, n1, n2);
		}
#else
		cout << ix << ":\t";
		indexToPat(ix, &pat[1]);
		for(int i = 1; i != pat.size()-1; ++i) cout << (int)pat[i];
		cout << "\t";
		for(int i = 0; i != N_HORZ; ++i) cout << (can_put_black(pat, i) ? "B" : ".");
		cout << "\t";
		for(int i = 0; i != N_HORZ; ++i) {
			int n1, n2;
			auto ix2 = put_black(ix, i, n1, n2);
			cout << ix2 << " ";
		}
		cout << "\t";
		for(int i = 0; i != N_HORZ; ++i) cout << (can_put_white(pat, i) ? "W" : ".");
		cout << "\t";
		for(int i = 0; i != N_HORZ; ++i) {
			int n1, n2;
			auto ix2 = put_white(ix, i, n1, n2);
			cout << ix2 << " ";
		}
		cout << "\n";
#endif
	}
}
//--------------------------------------------------------------------------------
void BoardIndex::init() {
	for(int i = 0; i != N_IX_HORZ; ++i) m_ix_horz[i] = 0;		//	全セル空欄
	for(int i = 0; i != N_IX_VERT; ++i) m_ix_vert[i] = 0;		//	全セル空欄
	for(int i = 0; i != N_IX_BL_UR; ++i) m_ix_bl_ur[i] = 0;		//	全セル空欄
	for(int i = 0; i != N_IX_UL_BR; ++i) m_ix_ul_br[i] = 0;		//	全セル空欄
	//
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
}

static const char *dig_str[] = {"１", "２", "３", "４", "５", "６"};
void BoardIndex::print() {
	vector<uchar> lst;
	cout << "＼ａｂｃｄｅｆ\n";
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
