//----------------------------------------------------------------------
//
//			File:			"ML.h"
//			Created:		05-9-2022
//			Author:			津田伸秀
//			Description:	評価関数計算・評価パラメータ機械学習用クラス宣言
//
//----------------------------------------------------------------------

#pragma once

#include <vector>
#include "Othello6x6.h"
#include "BoardBitboard.h"

#define		MAX_NP				8							//	最大着手可能数
#define		NPBW_TABLE_SZ		(MAX_NP+1)*(MAX_NP+1)

class ML {
public:
	enum {
		PAT_LINE = 0x01,
		PAT_CORNER8 = 0x02,
		N_LEGAL_MOVES = 0x04,
		DFLT_MODE = PAT_LINE | PAT_CORNER8 | N_LEGAL_MOVES,
	};
public:
	ML() { init(); }
public:
	void	clear_round_err2();
	void	init();
	//
	void	print_pat_vals() const;			//	パターン評価値（全タイプ共通）表示
	void	print_pat2_vals() const;			//	位置別パターン評価値表示
	void	print_npbw_vals() const;
	int		get_round() const { return m_round; }
	double	get_err2() const { return m_err2; }
	//
	double	eval(Bitboard black, Bitboard white, int mode = DFLT_MODE) const;			//	評価関数計算
	void	learn(Bitboard black, Bitboard white, int cv, int mode = DFLT_MODE);		//	評価値が cv に近づくよう１回学習
	//
	double	ev_pat_vals(Bitboard black, Bitboard white) const;			//	現 m_pat_val[] を用いて評価関数計算
	void	learn_pat_vals(Bitboard black, Bitboard white, int cv);		//	評価値が cv に近づくよう１回学習
	double	ev_pat2_vals(Bitboard black, Bitboard white) const;			//	現 m_pat2_val[][] を用いて評価関数計算
	void	learn_pat2_vals(Bitboard black, Bitboard white, int cv);	//	評価値が cv に近づくよう１回学習
	double	ev_pat2_corner8_vals(Bitboard black, Bitboard white) const;			//	現 m_pat2_val[][], m_corner8_val[] を用いて評価関数計算
	void	learn_pat2_corner8_vals(Bitboard black, Bitboard white, int cv);	//	評価値が cv に近づくよう１回学習
	double	ev_pat2_corner8_npbw_vals(Bitboard black, Bitboard white) const;		//	現 m_pat2_val[][], m_corner8_val[], を用いて評価関数計算
	void	learn_pat2_corner8_npbw_vals(Bitboard black, Bitboard white, int cv);	//	評価値が cv に近づくよう１回学習
public:
	int		m_round;			//	学習回数
	double	m_err2;				//	自乗誤差累計
	mutable int		m_npb;		//	黒着手可能箇所数
	mutable int		m_npw;		//	白着手可能箇所数
	mutable std::vector<int>	m_pat_ixes;			//	m_pat_val インデックスリスト
	mutable std::vector<int>	m_corner8_hv_ixes;		//	m_corner8_val インデックスリスト
	mutable std::vector<int>	m_corner8_vh_ixes;		//	m_corner8_val インデックスリスト
	int m_rev_index[N_PAT];					//	左右反転したパターンインデックス
	double m_pat_val[N_PAT];				//	パターン評価値（全タイプ共通）
	double m_pat2_val[N_PTYPE][N_PAT];		//	タイプ別パターン評価値
	double m_corner8_val[N_PAT8];			//	角８個パターン
	double m_npbw_val[NPBW_TABLE_SZ];		//	着手可能箇所数評価値テーブル、ix = npb + npw * 9、npb, npw は [0, 8]
};
