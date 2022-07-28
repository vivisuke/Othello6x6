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
	for(int i = 0; i != lst.size(); ++i) {
		index = index * 3 + lst[i];
	}
	return index;
}
void indexToPat(ushort index, std::vector<uchar> &lst, int len) {
	lst.resize(len);
	while( --len >= 0 ) {
		lst[len] = index % 3;
		index /= 3;
	}
}

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
	for(int y = 1; y != N_VERT+1; ++y) {
		cout << dig_str[y-1];
		indexToPat(m_ix_horz[y-1], lst);
		for(int x = 1; x != N_HORZ+1; ++x) {
			switch( lst[x-1] ) {
			case EMPTY: cout << "・";	break;
			case BLACK: cout << "Ｘ";	break;
			case WHITE: cout << "○";	break;
			}
		}
		cout << "\n";
	}
	cout << "\n";
}
