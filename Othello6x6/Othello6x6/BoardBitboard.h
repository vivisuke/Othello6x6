//----------------------------------------------------------------------
//
//			File:			"BoardBitboard.h"
//			Created:		25-7-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#pragma once

class BoardBitboard {
	typedef unsigned _int64	Bitboard;
public:
	BoardBitboard() { init(); }
public:
	void	init();
	void	print();
private:
	Bitboard	m_black;
	Bitboard	m_white;
};
