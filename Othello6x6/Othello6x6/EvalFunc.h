//----------------------------------------------------------------------
//
//			File:			"EvalFunc.h"
//			Created:		05-9-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#pragma once

#include "Othello6x6.h"

class EvalFunc {
public:
	EvalFunc() { init(); }
public:
	void	init();
public:
	int m_rev_index[N_PAT];			//	左右反転したパターンインデックス
	double m_pat_val[N_PAT];				//	パターン評価値（全タイプ共通）
	double m_pat2_val[N_PTYPE][N_PAT];		//	タイプ別パターン評価値
	double m_pat8_val[N_PAT8];				//	角８個パターン
	double m_npbw_val[NPBW_TABLE_SZ];		//	着手可能箇所数評価値テーブル、ix = npb + npw * 9、npb, npw は [0, 8]
};
