//----------------------------------------------------------------------
//
//			File:			"ML.cpp"
//			Created:		09-9-2022
//			Author:			津田伸秀
//			Description:	評価関数計算・評価パラメータ機械学習用クラス実装
//
//----------------------------------------------------------------------

#include <iostream>
#include <string>
#include "ML.h"
#include "BoardIndex.h"

using namespace std;

void ML::init() {
	for(int i = 0; i != N_PAT; ++i)			//	全直線パターン評価値
		m_pat_val[i] = 0.0;
	for(int t = 0; t != N_PTYPE; ++t)			//	位置別直線パターン評価値
		for(int i = 0; i != N_PAT; ++i)
			m_pat2_val[t][i] = 0.0;
	for(int i = 0; i != N_PAT8; ++i)		//	角８個パターン評価値
		m_pat_val[i] = 0.0;
	for(int i = 0; i != NPBW_TABLE_SZ; ++i)		//	着手可能箇所数評価値
		m_npbw_val[i] = 0.0;
}
void ML::print_pat_vals() const {
    string txt;
    for(int i = 0; i != N_PAT; ++i) {
    	auto t = to_string(m_pat_val[i]);
    	indexToPat(i, txt);
    	cout << t << "\t" << i << " " << txt << "\n";
    }
}
