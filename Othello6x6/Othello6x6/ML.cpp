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

#define		ML_PARAM		8			//	山登りパラメータ（誤差の逆数分修正）

void ML::clear_round_err2() {
	m_round = 0;
	m_err2 = 0.0;
}
void ML::init() {
	clear_round_err2();
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
//	現 m_pat_val[] を用いて評価関数計算
double ML::ev_pat_vals(Bitboard black, Bitboard white) const {
	//vector<int> lst;		//	パターンインデックス格納用配列
   	get_pat_indexes(black, white, m_pat_ixes);
   	double pv = 0.0;	//	パターンによる評価値
   	for(int k = 0; k != m_pat_ixes.size(); ++k) {
   		pv += m_pat_val[m_pat_ixes[k]];
   	}
   	return pv;
}
//	評価値が cv に近づくよう m_pat_val[] を１回学習
void ML::learn_pat_vals(Bitboard black, Bitboard white, int cv) {
	++m_round;
   	auto d = cv - ev_pat_vals(black, white);
   	m_err2 += d * d;
   	//	パターン評価値更新値
   	d /= m_pat_ixes.size() * ML_PARAM;
   	for(int k = 0; k != m_pat_ixes.size(); ++k) {
   		m_pat_val[m_pat_ixes[k]] += d;
   	}
}
