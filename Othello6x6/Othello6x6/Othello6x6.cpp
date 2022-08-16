#include <iostream>
#include <vector>
#include <random>
#include <chrono>
#include <assert.h>
#include "BoardArray.h"
#include "BoardBitboard.h"
#include "BoardIndex.h"

using namespace std;

long long	g_count;		//	末端ノード数
std::random_device g_rnd;     // 非決定的な乱数生成器を生成
std::mt19937 g_mt(g_rnd());     //  メルセンヌ・ツイスタの32ビット版、引数は初期シード値

void exp_game_tree(BoardArray&, int depth, bool black=true);		//	ゲーム木探索、depth for 残り深さ
void exp_game_tree(Bitboard black, Bitboard white, int depth, bool passed=false);		//	ゲーム木探索、depth for 残り深さ
void put_randomly(Bitboard black, Bitboard white, int depth, bool passed=false);		//	ランダムに手を進める、depth for 残り深さ

int main()
{
	//int d = 1;
	//cout << (0x10 << d) << "\n";
	//d = -1;
	//cout << (0x10 << d) << "\n";
#if 0
    BoardIndex bi;
    bi.print();
    buildIndexTable();
#endif
    //if( false ) {
	    BoardBitboard bb;
	    bb.put_black(E4_BIT);
	    bb.print();
    //}
#if 0
    for(int y = 0; y != N_VERT; ++y) {
    	for(int x = 0; x != N_HORZ; ++x) {
			auto rev = bb.get_revbits(xyToBit(x, y));
			if( rev != 0 ) cout << "B";
			else cout << ".";
    	}
    	cout << "\n";
    }
   	cout << "\n";
#endif
   	if( false ) {		//	10手先の局面数カウント
		auto start = std::chrono::system_clock::now();      // 計測スタート時刻
	   	exp_game_tree(bb.m_white, bb.m_black, 10);
	    auto end = std::chrono::system_clock::now();       // 計測終了時刻を保存
	    auto dur = end - start;        // 要した時間を計算
	    auto msec = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
	   	cout << "g_count = " << g_count << "\n";
	    cout << "dur = " << msec << "msec.\n";
   	}
   	if( true ) {
	   	//put_randomly(bb.m_white, bb.m_black, 15);	//	15 for 16個空き
	   	put_randomly(bb.m_white, bb.m_black, 21);	//	21 for 10個空き
   	}
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
    cout << "dur = " << msec << "msec.\n";
#endif
    //

    std::cout << "\nOK.\n";
}
//	ゲーム木探索、depth for 残り深さ
void exp_game_tree(Bitboard black, Bitboard white, int depth, bool passed) {
	if( depth == 0 ) {		//	末端局面
		//print(black, white);
		++g_count;
		return;
	}
	bool put = false;		//	着手箇所あり
	Bitboard spc = ~(black | white) & BB_MASK;		//	空欄箇所
	//	８近傍が白の場所のみ取り出す
	spc &= (white<<DIR_UL) | (white<<DIR_U) | (white<<DIR_UR) | (white<<DIR_L) | 
			(white>>DIR_UL) | (white>>DIR_U) | (white>>DIR_UR) | (white>>DIR_L);
	while( spc != 0 ) {
		Bitboard b = -(_int64)spc & spc;		//	最右ビットを取り出す
		auto rev = get_revbits(black, white, b);
		if( rev != 0 ) {
			put = true;
			exp_game_tree(white ^ rev, black | rev | b, depth - 1);
		}
		spc ^= b;		//	最右ビット消去
	}
	if( !put ) {		//	パスの場合
		if( !passed ) {		//	１手前がパスでない
			exp_game_tree(white, black, depth, true);
		} else {			//	１手前がパス → 双方パスで終局
			//print(black, white);
		}
	}
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
//	ランダムに手を進める、depth for 残り深さ
void put_randomly(Bitboard black, Bitboard white, int depth, bool passed) {
	if( depth == 0 ) {		//	末端局面
		print(black, white);
		return;
	}
	bool put = false;		//	着手箇所あり
	Bitboard spc = ~(black | white) & BB_MASK;		//	空欄箇所
	//	８近傍が白の場所のみ取り出す
	spc &= (white<<DIR_UL) | (white<<DIR_U) | (white<<DIR_UR) | (white<<DIR_L) | 
			(white>>DIR_UL) | (white>>DIR_U) | (white>>DIR_UR) | (white>>DIR_L);
	vector<Bitboard> lst;
	while( spc != 0 ) {
		Bitboard b = -(_int64)spc & spc;		//	最右ビットを取り出す
		auto rev = get_revbits(black, white, b);
		if( rev != 0 ) {
			lst.push_back(b);
			lst.push_back(rev);
		}
		spc ^= b;		//	最右ビット消去
	}
	if( lst.empty() ) {		//	パスの場合
		if( !passed ) {		//	１手前がパスでない
			put_randomly(white, black, depth, true);
		} else {			//	１手前がパス → 双方パスで終局
			print(black, white);
		}
	} else {
		int ix = (g_mt() % (lst.size()/2)) * 2;
		auto b = lst[ix];
		auto rev = lst[ix + 1];
		put_randomly(white ^ rev, black | rev | b, depth - 1);
	}
}
