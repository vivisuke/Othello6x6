//----------------------------------------------------------------------
//
//			File:			"ML.h"
//			Created:		05-9-2022
//			Author:			津田伸秀
//			Description:	評価関数計算・評価パラメータ機械学習用クラス宣言
//
//----------------------------------------------------------------------

#pragma once

#include "Othello6x6.h"

#define		MAX_NP				8							//	最大着手可能数
#define		NPBW_TABLE_SZ		(MAX_NP+1)*(MAX_NP+1)

class ML {
public:
	ML() { init(); }
public:
	void	init();
	void	print_pat_vals() const;			//	パターン評価値（全タイプ共通）表示
public:
	int m_rev_index[N_PAT];					//	左右反転したパターンインデックス
	double m_pat_val[N_PAT];				//	パターン評価値（全タイプ共通）
	double m_pat2_val[N_PTYPE][N_PAT];		//	タイプ別パターン評価値
	double m_pat8_val[N_PAT8];				//	角８個パターン
	double m_npbw_val[NPBW_TABLE_SZ];		//	着手可能箇所数評価値テーブル、ix = npb + npw * 9、npb, npw は [0, 8]
};
