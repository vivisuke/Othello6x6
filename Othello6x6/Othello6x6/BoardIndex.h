//----------------------------------------------------------------------
//
//			File:			"BoardIndex.h"
//			Created:		25-7-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#pragma once

#include <vector>
#include "Othello6x6.h"

#define		N_IX_HORZ		N_VERT		//	水平方向
#define		N_IX_VERT		N_HORZ		//	垂直方向
#define		N_IX_UL_BR		7			//	＼方向
#define		N_IX_BL_UR		7			//	／方向

/*
m_ix_ul_br：

    ix = 0
      ↓
　ａｂｃｄｅｆ
１・・／／／／←ix = 3
２・／／／／／←ix = 4
３／／／／／／←ix = 5
４／／／／／／←ix = 6
５／／／／／・
６／／／／・・

m_ix_bl_ur：

　ａｂｃｄｅｆ
１＼＼＼＼・・
２＼＼＼＼＼・
３＼＼＼＼＼＼←ix = 6
４＼＼＼＼＼＼←ix = 5
５・＼＼＼＼＼←ix = 4
６・・＼＼＼＼←ix = 3
       ↑
     ix = 0

*/

ushort patToIndex(const std::vector<uchar> &lst);
void indexToPat(ushort index, std::vector<uchar> &lst, int len = 6);

class BoardIndex {
public:
	BoardIndex() { init(); }
public:
	void	init();
	void	print();
private:
	ushort	m_ix_horz[N_IX_HORZ];
	ushort	m_ix_vert[N_IX_VERT];
	ushort	m_ix_bl_ur[N_IX_BL_UR];
	ushort	m_ix_ul_br[N_IX_UL_BR];
};
