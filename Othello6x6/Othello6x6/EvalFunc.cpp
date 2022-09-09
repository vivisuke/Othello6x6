//----------------------------------------------------------------------
//
//			File:			"EvalFunc.cpp"
//			Created:		09-9-2022
//			Author:			津田伸秀
//			Description:
//
//----------------------------------------------------------------------

#include "EvalFunc.h"

void EvalFunc::init() {
	for(int i = 0; i != N_PAT; ++i)
		m_pat_val[i] = 0.0;
}
