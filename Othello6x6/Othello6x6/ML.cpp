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

extern int g_pat_type[];

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
		m_corner8_val[i] = 0.0;
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
void ML::print_pat2_vals() const {
    cout << "[\n";
    string txt;
    for(int k = 0; k != N_PTYPE; ++k) {
	    cout << "  [\n  ";
	    for(int i = 0; i != N_PAT; ++i) {
	    	auto t = to_string(m_pat2_val[k][i]);
	    	//indexToPat(i, txt);
	    	//cout << t << "\t" << i << " " << txt << "\n";
	    	cout << t << ", ";
	    	if( (i+1)%9 == 0 ) cout << "\n  ";
	    }
	    cout << "],\n";
    }
    cout << "]\n";
}
void ML::print_npbw_vals() const {
    cout << "[\n";
    string txt;
    int ix = 0;
    for(int k = 0; k <= 8; ++k) {
	    cout << "  [  ";
	    for(int i = 0; i <= 8; ++i) {
	    	auto t = to_string(m_npbw_val[ix++]);
	    	cout << t << ", ";
	    }
	    cout << "],\n";
    }
    cout << "]\n";
}
//	現 m_pat_val[] を用いて評価関数計算
double ML::ev_pat_vals(Bitboard black, Bitboard white) const {
	//vector<int> lst;		//	パターンインデックス格納用配列
    double pv = 0.0;	//	パターンによる評価値
    get_pat_indexes(black, white, m_pat_ixes);
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
//	現 m_pat2_val[] を用いて評価関数計算
double ML::ev_pat2_vals(Bitboard black, Bitboard white) const {
	//vector<int> lst;		//	パターンインデックス格納用配列
    double pv = 0.0;	//	パターンによる評価値
    get_pat_indexes(black, white, m_pat_ixes);
   	for(int k = 0; k != m_pat_ixes.size(); ++k) {
   		pv += m_pat2_val[g_pat_type[k]][m_pat_ixes[k]];
   	}
   	return pv;
}
//	評価値が cv に近づくよう m_pat2_val[][] を１回学習
void ML::learn_pat2_vals(Bitboard black, Bitboard white, int cv) {
	++m_round;
   	auto d = cv - ev_pat2_vals(black, white);
   	m_err2 += d * d;
   	//	パターン評価値更新値
   	d /= m_pat_ixes.size() * ML_PARAM;
   	for(int k = 0; k != m_pat_ixes.size(); ++k) {
   		m_pat2_val[g_pat_type[k]][m_pat_ixes[k]] += d;
   	}
}
//	現 m_pat2_val[], m_corner8_val を用いて評価関数計算
double ML::ev_pat2_corner8_vals(Bitboard black, Bitboard white) const {
	//vector<int> lst;		//	パターンインデックス格納用配列
    double pv = 0.0;	//	パターンによる評価値
    get_pat_indexes(black, white, m_pat_ixes);
   	for(int k = 0; k != m_pat_ixes.size(); ++k) {
   		pv += m_pat2_val[g_pat_type[k]][m_pat_ixes[k]];
   	}
   	get_corner8_indexes_hv(black, white, m_corner8_hv_ixes);
   	for(int k = 0; k != m_corner8_hv_ixes.size(); ++k) {
        //auto ix = m_corner8_hv_ixes[k];
   		pv += m_corner8_val[m_corner8_hv_ixes[k]];
   	}
   	return pv;
}
//	評価値が cv に近づくよう m_pat2_val[][], m_corner8_val[] を１回学習
void ML::learn_pat2_corner8_vals(Bitboard black, Bitboard white, int cv) {
	++m_round;
   	auto d = cv - ev_pat2_corner8_vals(black, white);
   	m_err2 += d * d;
   	//	パターン評価値更新値
   	d /= (m_pat_ixes.size() + m_corner8_hv_ixes.size()) * ML_PARAM;
   	for(int k = 0; k != m_pat_ixes.size(); ++k) {
   		m_pat2_val[g_pat_type[k]][m_pat_ixes[k]] += d;
   	}
   	get_corner8_indexes_vh(black, white, m_corner8_vh_ixes);
   	for(int k = 0; k != m_corner8_hv_ixes.size(); ++k) {
   		m_corner8_val[m_corner8_vh_ixes[k]] = m_corner8_val[m_corner8_hv_ixes[k]] += d;
   	}
}
//	現 m_pat2_val[], m_corner8_val[], m_npbw_val[] を用いて評価関数計算
double ML::ev_pat2_corner8_npbw_vals(Bitboard black, Bitboard white) const {
	//vector<int> lst;		//	パターンインデックス格納用配列
    double pv = 0.0;	//	パターンによる評価値
    get_pat_indexes(black, white, m_pat_ixes);
   	for(int k = 0; k != m_pat_ixes.size(); ++k) {
   		pv += m_pat2_val[g_pat_type[k]][m_pat_ixes[k]];
   	}
   	get_corner8_indexes_hv(black, white, m_corner8_hv_ixes);
   	for(int k = 0; k != m_corner8_hv_ixes.size(); ++k) {
        //auto ix = m_corner8_hv_ixes[k];
   		pv += m_corner8_val[m_corner8_hv_ixes[k]];
   	}
   	//	着手可能箇所数
   	m_npb = num_place_can_put_black(black, white);
   	m_npw = num_place_can_put_black(white, black);
	pv += m_npbw_val[m_npb + m_npw*(MAX_NP + 1)];
   	return pv;
}
//	評価値が cv に近づくよう m_pat2_val[][], m_corner8_val[], m_npbw_val[] を１回学習
void ML::learn_pat2_corner8_npbw_vals(Bitboard black, Bitboard white, int cv) {
	++m_round;
   	auto d = cv - ev_pat2_corner8_npbw_vals(black, white);
   	m_err2 += d * d;
   	//	パターン評価値更新値
   	d /= (m_pat_ixes.size() + m_corner8_hv_ixes.size() + 1) * ML_PARAM;
   	for(int k = 0; k != m_pat_ixes.size(); ++k) {
   		m_pat2_val[g_pat_type[k]][m_pat_ixes[k]] += d;
   	}
   	get_corner8_indexes_vh(black, white, m_corner8_vh_ixes);
   	for(int k = 0; k != m_corner8_hv_ixes.size(); ++k) {
   		m_corner8_val[m_corner8_vh_ixes[k]] = m_corner8_val[m_corner8_hv_ixes[k]] += d;
   	}
   	m_npbw_val[m_npb + m_npw*(MAX_NP+1)] += d;
}
