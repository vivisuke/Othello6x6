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
	m_black = C4_BIT | D3_BIT;
	m_white = C3_BIT | D4_BIT;
}
static const char *dig_str[] = {"１", "２", "３", "４", "５", "６"};
void BoardBitboard::print() const {
	cout << "＼ａｂｃｄｅｆ\n";
	for(int y = 0; y != N_VERT; ++y) {
		cout << dig_str[y];
		for(int x = 0; x != N_HORZ; ++x) {
			auto bit = xyToBit(x, y);
			if( (m_black & bit) != 0 ) cout << "Ｘ";
			else if( (m_white & bit) != 0 ) cout << "○";
			else cout << "・";
		}
		cout << "\n";
	}
}
