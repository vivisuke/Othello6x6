﻿#include <iostream>
#include <chrono>
#include <assert.h>
#include "BoardArray.h"
#include "BoardBitboard.h"
#include "BoardIndex.h"

using namespace std;

long long	g_count;		//	末端ノード数
void exp_game_tree(BoardArray&, int depth, bool black=true);		//	ゲーム木探索、depth for 残り深さ

int main()
{
#if 0
    BoardIndex bi;
    bi.print();
    buildIndexTable();
#endif
    BoardBitboard bb;
    bb.print();
#if 0
    BoardArray ba;
    ba.print();
    for(int y = 1; y != N_VERT+1; ++y)
	    cout << ba.toIndex(1, y, 1) << "\n";
#endif
#if 0
	//
	//int ix = xyToIndex(3, 2);
	//ba.can_put_sub_BLACK(ix, ARY_WIDTH);
	for(int y = 1; y != N_VERT+1; ++y) {
		for(int x = 1; x != N_HORZ+1; ++x) {
			cout << (ba.can_put_BLACK(x, y) ? "B" : ".");
		}
		cout << "\n";
	}
	cout << "\n";
	for(int y = 1; y != N_VERT+1; ++y) {
		for(int x = 1; x != N_HORZ+1; ++x) {
			cout << (ba.can_put_WHITE(x, y) ? "W" : ".");
		}
		cout << "\n";
	}
	cout << "\n";
	//
	ba.put_BLACK(5, 4);
    ba.print();
	ba.put_WHITE(3, 5);
    ba.print();
    ba.un_put_WHITE();
    ba.print();
    ba.un_put_BLACK();
    ba.print();
#endif
    //
#if	0
    g_count = 0;
	const int depth = 5;
	cout << "depth = " << depth << "\n";
	auto start = std::chrono::system_clock::now();      // 計測スタート時刻
    exp_game_tree(ba, depth);
    auto end = std::chrono::system_clock::now();       // 計測終了時刻を保存
    auto dur = end - start;        // 要した時間を計算
    auto msec = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
    cout << "count = " << g_count << "\n";
    cout << "dur = " << msec << "sec.\n";
#endif
    //

    std::cout << "\nOK.\n";
}
//	ゲーム木探索、depth for 残り深さ
void exp_game_tree(BoardArray& bd, int depth, bool black_turn) {
#if 0
	if( depth == 0 ) {		//	末端局面
		//bd.print();
		++g_count;
		return;
	}
#else
	if (depth == 1) {
		for(int ix = xyToIndex(1, 1); ix <= xyToIndex(N_HORZ, N_VERT); ++ix) {
			if( black_turn ) {
				if( bd.can_put_BLACK(ix) ) {
					++g_count;
				}
			} else {
				if( bd.can_put_WHITE(ix) ) {
					++g_count;
				}
			}
		}
		return;
	}
#endif
	for(int ix = xyToIndex(1, 1); ix <= xyToIndex(N_HORZ, N_VERT); ++ix) {
		if( black_turn ) {
			if( bd.put_BLACK(ix) ) {
				exp_game_tree(bd, depth-1, !black_turn);
				bd.un_put_BLACK();
			}
		} else {
			if( bd.put_WHITE(ix) ) {
				exp_game_tree(bd, depth-1, !black_turn);
				bd.un_put_WHITE();
			}
		}
	}
}
