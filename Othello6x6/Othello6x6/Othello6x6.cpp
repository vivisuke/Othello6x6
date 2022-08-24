﻿#include <iostream>
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
//std::mt19937 g_mt(1);     //  メルセンヌ・ツイスタの32ビット版、引数は初期シード値

void init(Bitboard &black, Bitboard &white) {
	black = C4_BIT | D3_BIT;
	white = C3_BIT | D4_BIT;
}
void exp_game_tree(BoardArray&, int depth, bool black=true);		//	ゲーム木探索、depth for 残り深さ
void exp_game_tree(Bitboard black, Bitboard white, int depth, bool passed=false);		//	ゲーム木探索、depth for 残り深さ
void put_randomly(Bitboard &black, Bitboard &white, int depth, bool passed=false);		//	ランダムに手を進める、depth for 残り深さ
int perfect_game(Bitboard black, Bitboard white, bool=false);		//	最善手で終局まで進める

int main()
{
	assert( xyToBit(N_HORZ-1, N_VERT-1) == 1 );
	assert( xyToBit(0, N_VERT-1) == 0x20 );
	assert( xyToBit(0, 0) == ((Bitboard)0x20<<40) );
	assert( xyToBit(2, 3) == C4_BIT );
	assert( bitToX(1) == N_HORZ - 1 );				//	f6
	assert( bitToY(1) == N_VERT - 1 );
	assert( bitToX(((Bitboard)0x20<<40)) == 0 );	//	a1
	assert( bitToY(((Bitboard)0x20<<40)) == 0 );
	assert( bitToX(C4_BIT) == 2 );
	assert( bitToY(C4_BIT) == 3 );
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
	    BoardBitboard bb;
	    bb.put_black(E4_BIT);
	    bb.print();
		auto start = std::chrono::system_clock::now();      // 計測スタート時刻
	   	exp_game_tree(bb.m_white, bb.m_black, 10);
	    auto end = std::chrono::system_clock::now();       // 計測終了時刻を保存
	    auto dur = end - start;        // 要した時間を計算
	    auto msec = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
	   	cout << "g_count = " << g_count << "\n";
	    cout << "dur = " << msec << "msec.\n";
   	}
   	if( false ) {
   		Bitboard black, white;
   		init(black, white);
	   	//put_randomly(white, black, 16);	//	16 for 16個空き
	   	//put_randomly(white, black, 22);	//	22 for 10個空き
	   	//put_randomly(white, black, 24);	//	24 for 8個空き
	   	put_randomly(white, black, 29);	//	29 for 3個空き
	   	//put_randomly(white, black, 30);	//	30 for 2個空き
	   	print(black, white);
	   	int ev = 0;
	   	auto pos = negaAlpha(black, white, ev);
	   	cout << "ev = " << ev << "\n";
	   	cout << "pos = " << (char)('a'+bitToX(pos)) << (char)('1'+bitToY(pos)) << "\n";
   	}
   	if( false ) {
   		Bitboard black, white;
   		init(black, white);
	   	//put_randomly(white, black, 12);	//	12 for 20個空き
	   	//put_randomly(white, black, 16);	//	16 for 16個空き
	   	put_randomly(white, black, 24);	//	24 for 8個空き
	   	print(black, white);
	   	int ev = 0;
	   	auto pos = negaAlpha(black, white, ev);
	   	cout << "ev = " << ev << "\n";
	   	cout << "pos = " << (char)('a'+bitToX(pos)) << (char)('1'+bitToY(pos)) << "\n";
   	}
   	if( false ) {
   		Bitboard black, white;
   		init(black, white);
	   	//put_randomly(black, white, 16);		//	16個空き
	   	//put_randomly(black, white, 22);	//	10個空き
	   	put_randomly(black, white, 24);	//	24 for 8個空き
	   	cout << bb_to_string(black) << " " << bb_to_string(white) << "\n";
	   	//put_randomly(black, white, 28);	//	28 for 4個空き
	   	perfect_game(black, white);
   	}
   	if( true ) {
   		Bitboard black, white;
		auto start = std::chrono::system_clock::now();      // 計測スタート時刻
		const int N = 10000;
		int sum = 0;
		int sum2 = 0;
   		for(int i = 0; i != N; ++i) {
	   		init(black, white);
		   	put_randomly(black, white, 24);	//	24 for 8個空き
		   	int ev = 0;
		   	auto pos = negaAlpha(black, white, ev);
		   	//int ev = perfect_game(black, white);
		   	sum += ev;
		   	sum2 += ev * ev;
		   	cout << bb_to_string(black) << " " << bb_to_string(white) << " " << ev << "\n";
   		}
	    auto end = std::chrono::system_clock::now();       // 計測終了時刻を保存
	    auto dur = end - start;        // 要した時間を計算
	    auto msec = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
	    cout << "\n";
	    cout << "# N = " << N << "\n";
	    cout << "# dur = " << msec << "msec.\n\n";
	    auto avg = (double)sum/N;
	    auto sigma2 = (double)sum2/N - avg*avg;
	    cout << "# avg(ev) = " << avg << "\n";
	    cout << "# sigma = " << sqrt(sigma2) << "\n";
	    //cout << "# sigma^2 = " << sigma2 << "\n";
   	}
   	if( false ) {
   		//Bitboard black = 0x042910080c3e;		//	8個空き
   		//Bitboard white = 0x32140f173000;
   		Bitboard black = 0x070f050b013e;		//	2個空き
   		Bitboard white = 0x38303a143e00;
   		print(black, white);
	   	int ev = 0;
	   	auto pos = negaAlpha(black, white, ev);
	   	cout << "ev = " << ev << "\n";
	   	cout << "pos = " << (char)('a'+bitToX(pos)) << (char)('1'+bitToY(pos)) << "\n";
	   	//int ev = perfect_game(black, white, true);
	   	//cout << bb_to_string(black) << " " << bb_to_string(white) << " " << ev << "\n";
   	}
   	if( false ) {
   		Bitboard black = 0x042910080c3e;
   		Bitboard white = 0x32140f173000;
   		print(black, white);
	   	int ev = perfect_game(black, white, true);
	   	cout << bb_to_string(black) << " " << bb_to_string(white) << " " << ev << "\n";
   	}
   	if( false ) {
   		Bitboard black, white;
   		init(black, white);
	   	put_randomly(black, white, 24);	//	24 for 8個空き
   		print(black, white);
   		cout << "\nhorizontal:\n";
   		for(int y = 0; y != N_VERT; ++y) {
   			int index = get_pat_index(black, white, xyToBit(0, y), DIR_L);
   			cout << "  " << y << ": " << index << "\n";
   		}
   		cout << "\nvertical:\n";
   		for(int x = 0; x != N_HORZ; ++x) {
   			int index = get_pat_index(black, white, xyToBit(x, 0), DIR_U);
   			cout << "  " << x << ": " << index << "\n";
   		}
   		cout << "\ndiagonal(／):\n";
   		for(int x = 2; x != N_HORZ; ++x) {
   			int index = get_pat_index(black, white, xyToBit(x, 0), DIR_UR);
   			cout << "  " << x << ": " << index << "\n";
   		}
   		for(int y = 1; y != N_VERT-2; ++y) {
   			int index = get_pat_index(black, white, xyToBit(N_HORZ-1, y), DIR_UR);
   			cout << "  " << y << ": " << index << "\n";
   		}
   		cout << "\ndiagonal(＼):\n";
   		for(int x = N_HORZ-2; --x >= 0;) {
   			int index = get_pat_index(black, white, xyToBit(x, 0), DIR_UL);
   			cout << "  " << x << ": " << index << "\n";
   		}
   		for(int y = 1; y != N_VERT-2; ++y) {
   			int index = get_pat_index(black, white, xyToBit(0, y), DIR_UL);
   			cout << "  " << y << ": " << index << "\n";
   		}
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
void put_randomly(Bitboard &black, Bitboard &white, int depth, bool passed) {
	if( depth == 0 ) {		//	末端局面
		//print(black, white);
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
			//print(black, white);
		}
	} else {
		int ix = (g_mt() % (lst.size()/2)) * 2;
		auto b = lst[ix];
		auto rev = lst[ix + 1];
		black |= b | rev;
		white ^= rev;
		put_randomly(white, black, depth - 1);
	}
}
int perfect_game(Bitboard black, Bitboard white, bool verbose) {
	bool passed = false;
   	int alpha;
	for(bool rev = false; ; rev = !rev) {
		if( verbose ) {
			if( !rev ) {
				cout << bb_to_string(black) << " " << bb_to_string(white) << "\n";
				print(black, white);
			} else {
				cout << bb_to_string(white) << " " << bb_to_string(black) << "\n";
				print(white, black);
			}
		}
	   	if( popcount(black) + popcount(white) == N_HORZ*N_VERT ) break;
	   	alpha = 0;
	   	auto pos = negaAlpha(black, white, alpha);
	   	if( pos == 0 ) {
			if (passed) {	//	双方パス
				int bc = popcount(black);
				int wc = popcount(white);
				alpha = bc - wc;
				Bitboard spc = ~(black | white) & BB_MASK;		//	空欄箇所
				if( spc != 0 ) {	//	空欄ありの場合
					if( bc > wc ) alpha += popcount(spc);
					else if( bc < wc ) alpha -= popcount(spc);
				}
			   	cout << "alpha = " << alpha << "\n";
				break;
			}
	   		passed = true;
	   		if( verbose )
		   		cout << "pass\n\n";
	   	} else {
	   		passed = false;
	   		if( verbose ) {
			   	cout << "alpha = " << alpha << "\n";
			   	cout << "pos = " << (char)('a'+bitToX(pos)) << (char)('1'+bitToY(pos)) << "\n\n";
	   		}
	   	}
	   	put_black(black, white, pos);
	   	std::swap(black, white);
	}
	return alpha;
}
