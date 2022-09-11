#include <iostream>
#include <string>
#include <vector>
#include <random>
#include <chrono>
#include <assert.h>
#include "Othello6x6.h"
#include "BoardArray.h"
#include "BoardBitboard.h"
#include "BoardIndex.h"
#include "ML.h"

using namespace std;

long long	g_count;		//	末端ノード数
std::random_device g_rnd;     // 非決定的な乱数生成器を生成
std::mt19937 g_mt(g_rnd());     //  メルセンヌ・ツイスタの32ビット版、引数は初期シード値
//std::mt19937 g_mt(1);     //  メルセンヌ・ツイスタの32ビット版、引数は初期シード値

#define		MAX_NP				8
#define		NPBW_TABLE_SZ		(MAX_NP+1)*(MAX_NP+1)

double g_cnto_slope = 1.0;			//	評価値 = 準確定石数差 * g_cnto_slope
int g_rev_index[N_PAT];			//	左右反転したパターンインデックス
double g_pat_val[N_PAT];				//	（全位置共通）直線パターン評価値
double g_pat2_val[N_PTYPE][N_PAT];
double g_pat8_val[N_PAT8];				//	角８個パターン
double g_npbw_val[NPBW_TABLE_SZ];		//	着手可能箇所数評価値テーブル、ix = npb + npw * 9、npb, npw は [0, 8]
int g_pat_type[] = {
	PTYPE_LINE1, PTYPE_LINE2, PTYPE_LINE3, PTYPE_LINE3, PTYPE_LINE2, PTYPE_LINE1, 
	PTYPE_LINE1, PTYPE_LINE2, PTYPE_LINE3, PTYPE_LINE3, PTYPE_LINE2, PTYPE_LINE1, 
	PTYPE_DIAG3, PTYPE_DIAG4, PTYPE_DIAG5, PTYPE_DIAG6, PTYPE_DIAG5, PTYPE_DIAG4, PTYPE_DIAG3, 
	PTYPE_DIAG3, PTYPE_DIAG4, PTYPE_DIAG5, PTYPE_DIAG6, PTYPE_DIAG5, PTYPE_DIAG4, PTYPE_DIAG3, 
};

void exp_game_tree(BoardArray&, int depth, bool black=true);		//	ゲーム木探索、depth for 残り深さ
void exp_game_tree(Bitboard black, Bitboard white, int depth, bool passed=false);		//	ゲーム木探索、depth for 残り深さ
bool put_randomly(Bitboard &black, Bitboard &white, int depth, bool passed=false);		//	ランダムに手を進める、depth for 残り深さ
int perfect_game(Bitboard black, Bitboard white, bool=false);		//	最善手で終局まで進める
//void indexToPat(int index, string& pat);
void print_pat_val(int, bool=false);		//	パターン評価値テーブル値表示
void print_npbw_table();		//	着手可能箇所数評価値テーブル値表示

void init(Bitboard &black, Bitboard &white) {
	black = C4_BIT | D3_BIT;
	white = C3_BIT | D4_BIT;
}
string double2string(double v) {
	string txt = to_string(v);
	if( v >= 0.0 ) txt = '+' + txt;
	//if( txt.size() > 9 ) txt = txt.substr(0, 9);
	if( abs(v) < 10.0 ) txt = ' ' + txt;
	return txt;
}
void build_rev_index() {
	vector<uchar> lst;
	//string txt, rtxt;
	for(int ix = 0; ix != N_PAT; ++ix) {
		indexToPat(ix, lst);
		//indexToPat(ix, txt);
		std::reverse(lst.begin(), lst.end());
		auto rix = patToIndex(lst);
		//indexToPat(rix, rtxt);
		//cout << ix << " " << txt << " " << rix << " " << rtxt << "\n";
		g_rev_index[ix] = rix;
	}
}

//	直線パターン・コーナー８個パターン・着手可能箇所数・準確定石数評価、手番：黒
double eval_pat_corner8_ncanput_ncnto(Bitboard black, Bitboard white,
									int& npb, int& npw,		//	着手可能箇所数
									int& nb, int& nw) {		//	準確定石数
	vector<int> lst, lst8;
   	double pv = 0.0;
   	//	縦横斜め直線パターンによる評価値
   	get_pat_indexes(black, white, lst);
   	for(int k = 0; k != lst.size(); ++k) {
   		pv += g_pat2_val[g_pat_type[k]][lst[k]];
   	}
   	//	コーナー８箇所評価
   	get_corner_indexes_hv(black, white, lst8);
   	for(int k = 0; k != lst8.size(); ++k) {
   		pv += g_pat8_val[lst8[k]];
   	}
   	//	着手可能箇所数
   	npb = num_place_can_put_black(black, white);
   	npw = num_place_can_put_black(white, black);
	pv += g_npbw_val[npb + npw * (MAX_NP + 1)];
	//	準確定石数差
	//int nb, nw;
	get_num_cannot_turnover(black, white, nb, nw);
	pv += g_cnto_slope * (nb - nw);
	//return (int)round(pv);
	return pv;
}

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
	build_rev_index();
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
   	if( false ) {
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
   		Bitboard black, white;
   		init(black, white);
   		assert( num_place_can_put_black(black, white) == 4 );
   		assert( num_place_can_put_black(white, black) == 4 );
	   	put_randomly(black, white, 24);	//	24 for 8個空き
	   	print(black, white);
		cout << "np black = " << num_place_can_put_black(black, white) << "\n";
		cout << "np white = " << num_place_can_put_black(white, black) << "\n";
   	}
   	if( false ) {
   		Bitboard black, white;
		auto start = std::chrono::system_clock::now();      // 計測スタート時刻
		const int  ITR = 30;
		const int N = 1000;
		const int TOTAL = ITR * N;
		double sum2 = 0;
   		for(int i = 0; i != N; ++i) {
	   		init(black, white);
		   	put_randomly(black, white, 24);	//	24 for 8個空き
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	sum2 += ev * ev;
   		}
   		cout << "0: sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		sum2 = 0;
		vector<int> lst;
   		for(int i = 0; i != TOTAL; ++i) {
	   		init(black, white);
		   	put_randomly(black, white, 24);	//	24 for 8個空き
		   	get_pat_indexes(black, white, lst);
		   	double pv = 0.0;	//	パターンによる評価値
		   	for(int k = 0; k != lst.size(); ++k) {
		   		pv += g_pat_val[lst[k]];
		   	}
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	//int ev = perfect_game(black, white);
			//cout << "pv = " << pv << ", ev = " << ev << "\n";
		   	auto d = ev - pv;
		   	sum2 += d * d;
		   	d /= 26 * 8;		//	パターン評価値更新値
		   	for(int k = 0; k != lst.size(); ++k) {
		   		g_pat_val[lst[k]] += d;
		   	}
		   	if( (i % N) == N - 1 ) {
		   		cout << (i/N+1) << ": sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		   		sum2 = 0.0;
		   	}
		   	//cout << bb_to_string(black) << " " << bb_to_string(white) << " " << ev << "\n";
   		}
	    auto end = std::chrono::system_clock::now();       // 計測終了時刻を保存
	    auto dur = end - start;        // 要した時間を計算
	    auto msec = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
	    cout << "\n";
	    //cout << "# total = " << N << "\n";
	    cout << "# dur = " << msec << "msec.\n\n";

#if 0
	    string txt;
	    for(int i = 0; i != N_PAT; ++i) {
	    	auto t = to_string(g_pat_val[i]);
	    	indexToPat(i, txt);
	    	cout << t << "\t" << i << " " << txt << "\n";
	    }
#endif
   	}
   	if( false ) {
   		//	直線パターン評価値学習
   		Bitboard black, white;
		auto start = std::chrono::system_clock::now();      // 計測スタート時刻
		const int  ITR = 30;
		const int N = 10000;
		const int TOTAL = ITR * N;
		double sum2 = 0;
   		for(int i = 0; i != N; ++i) {
	   		init(black, white);
		   	put_randomly(black, white, 24);	//	24 for 8個空き
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	sum2 += ev * ev;
   		}
   		cout << "0: sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		sum2 = 0;
		vector<int> lst;
   		for(int i = 0; i != TOTAL; ++i) {
	   		init(black, white);
		   	while( !put_randomly(black, white, 24) ) {	//	24 for 8個空き
		   		init(black, white);
		   	}
		   	get_pat_indexes(black, white, lst);
		   	double pv = 0.0;	//	パターンによる評価値
		   	for(int k = 0; k != lst.size(); ++k) {
		   		pv += g_pat2_val[g_pat_type[k]][lst[k]];
		   	}
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	//int ev = perfect_game(black, white);
			//cout << "pv = " << pv << ", ev = " << ev << "\n";
		   	auto d = ev - pv;
		   	sum2 += d * d;
		   	d /= 26 * 8;		//	パターン評価値更新値
		   	for(int k = 0; k != lst.size(); ++k) {
		   		auto type = g_pat_type[k];
		   		g_pat2_val[type][lst[k]] += d;
		   		if( type <= PTYPE_LINE3 || type == PTYPE_DIAG6 ) {
		   			auto ix2 = g_rev_index[lst[k]];
		   			if( ix2 != lst[k] )
				   		g_pat2_val[type][ix2] += d;
		   		}
		   	}
		   	if( (i % N) == N - 1 ) {
		   		cout << (i/N+1) << ": sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		   		sum2 = 0.0;
		   	}
		   	//cout << bb_to_string(black) << " " << bb_to_string(white) << " " << ev << "\n";
   		}
	    auto end = std::chrono::system_clock::now();       // 計測終了時刻を保存
	    auto dur = end - start;        // 要した時間を計算
	    auto msec = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
	    cout << "\n";
	    //cout << "# total = " << N << "\n";
	    cout << "# dur = " << msec << "msec.\n\n";

#if 1
	    string txt;
	    for(int i = 0; i != N_PAT; ++i) {
	    	auto t = to_string(g_pat2_val[PTYPE_LINE1][i]);
	    	//auto t = to_string(g_pat2_val[PTYPE_DIAG6][i]);
	    	indexToPat(i, txt);
	    	cout << t << "\t" << i << " " << txt << "\n";
	    }
#endif
   	}
   	if( false ) {
   		//	直線パターン・着手可能箇所数評価値学習
   		Bitboard black, white;
		auto start = std::chrono::system_clock::now();      // 計測スタート時刻
		const int  ITR = 100;
		const int N = 10000;
		const int TOTAL = ITR * N;
		double sum2 = 0;
   		for(int i = 0; i != N; ++i) {
	   		init(black, white);
		   	put_randomly(black, white, 24);	//	24 for 8個空き
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	sum2 += ev * ev;
   		}
   		cout << "0: sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		sum2 = 0;
		vector<int> lst;
   		for(int i = 0; i != TOTAL; ++i) {
	   		init(black, white);
		   	while( !put_randomly(black, white, 24) ) {	//	24 for 8個空き
		   		init(black, white);
		   	}
		   	get_pat_indexes(black, white, lst);
		   	double pv = 0.0;	//	パターンによる評価値
		   	for(int k = 0; k != lst.size(); ++k) {
		   		pv += g_pat2_val[g_pat_type[k]][lst[k]];
		   	}
		   	auto npb = num_place_can_put_black(black, white);
		   	auto npw = num_place_can_put_black(white, black);
#if 0
		   	//if( npb == 0 && npw == 8 )
		   	if( npb == 8 && npw == 0 )
		   	{
		   		print(black, white);
			   	int ev = 0;			//	完全読みによる石差
			   	negaAlpha(black, white, ev);
			   	cout << "ev1 = " << ev << "\n";
				negaAlpha(white, black,  ev);
				cout << "ev2 = " << ev << "\n";
				cout << "\n";
		   	}
#endif
			pv += g_npbw_val[npb + npw * (MAX_NP + 1)];
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	//int ev = perfect_game(black, white);
			//cout << "pv = " << pv << ", ev = " << ev << "\n";
		   	auto d = ev - pv;
		   	sum2 += d * d;
		   	d /= 27 * 8;		//	パターン評価値更新値
		   	for(int k = 0; k != lst.size(); ++k) {
		   		auto type = g_pat_type[k];
		   		g_pat2_val[type][lst[k]] += d;
	   			auto ix2 = g_rev_index[lst[k]];
	   			switch( type ) {
	   			case PTYPE_DIAG5: ix2 /= 3;	break;
	   			case PTYPE_DIAG4: ix2 /= 9;	break;
	   			case PTYPE_DIAG3: ix2 /= 27;	break;
	   			}
	   			if( ix2 != lst[k] )
			   		g_pat2_val[type][ix2] += d;
		   		//if( type <= PTYPE_LINE3 || type == PTYPE_DIAG6 ) {
		   		//	if( ix2 != lst[k] )
				//   		g_pat2_val[type][ix2] += d;
		   		//}
		   	}
		   	g_npbw_val[npb + npw * (MAX_NP+1)] += d;
		   	if( (i % N) == N - 1 ) {
		   		cout << (i/N+1) << ": sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		   		sum2 = 0.0;
		   	}
		   	//cout << bb_to_string(black) << " " << bb_to_string(white) << " " << ev << "\n";
   		}
	    auto end = std::chrono::system_clock::now();       // 計測終了時刻を保存
	    auto dur = end - start;        // 要した時間を計算
	    auto msec = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
	    cout << "\n";
	    //cout << "# total = " << N << "\n";
	    cout << "# dur = " << msec << "msec.\n\n";

	    cout << "PAT LINE1:\n";
	    print_pat_val(PTYPE_LINE1);
	    cout << "PAT LINE2:\n";
	    print_pat_val(PTYPE_LINE2);
	    cout << "PAT LINE3:\n";
	    print_pat_val(PTYPE_LINE3, true);
	    cout << "PAT DIAG6:\n";
	    print_pat_val(PTYPE_DIAG6, true);
	    //
   		print_npbw_table();
   	}
   	if( false ) {
   		//	着手可能箇所数評価値学習
   		Bitboard black, white;
		auto start = std::chrono::system_clock::now();      // 計測スタート時刻
		const int  ITR = 20;
		const int N = 10000;
		const int TOTAL = ITR * N;
		double sum2 = 0;
   		for(int i = 0; i != N; ++i) {
	   		init(black, white);
		   	put_randomly(black, white, 24);	//	24 for 8個空き
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	sum2 += ev * ev;
   		}
   		cout << "0: sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		sum2 = 0;
		vector<int> lst;
   		for(int i = 0; i != TOTAL; ++i) {
	   		init(black, white);
		   	while( !put_randomly(black, white, 24) ) {	//	24 for 8個空き
		   		init(black, white);
		   	}
		   	get_pat_indexes(black, white, lst);
		   	double pv = 0.0;	//	パターンによる評価値
		   	//for(int k = 0; k != lst.size(); ++k) {
		   	//	pv += g_pat2_val[g_pat_type[k]][lst[k]];
		   	//}
		   	auto npb = num_place_can_put_black(black, white);
		   	auto npw = num_place_can_put_black(white, black);
			pv += g_npbw_val[npb + npw * (MAX_NP + 1)];
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	//int ev = perfect_game(black, white);
			//cout << "pv = " << pv << ", ev = " << ev << "\n";
		   	auto d = ev - pv;
		   	sum2 += d * d;
		   	d /= 1 * 8;		//	パターン評価値更新値
#if 0
		   	for(int k = 0; k != lst.size(); ++k) {
		   		auto type = g_pat_type[k];
		   		g_pat2_val[type][lst[k]] += d;
	   			auto ix2 = g_rev_index[lst[k]];
	   			switch( type ) {
	   			case PTYPE_DIAG5: ix2 /= 3;	break;
	   			case PTYPE_DIAG4: ix2 /= 9;	break;
	   			case PTYPE_DIAG3: ix2 /= 27;	break;
	   			}
	   			if( ix2 != lst[k] )
			   		g_pat2_val[type][ix2] += d;
		   		//if( type <= PTYPE_LINE3 || type == PTYPE_DIAG6 ) {
		   		//	if( ix2 != lst[k] )
				//   		g_pat2_val[type][ix2] += d;
		   		//}
		   	}
#endif
		   	g_npbw_val[npb + npw * (MAX_NP+1)] += d;
		   	if( (i % N) == N - 1 ) {
		   		cout << (i/N+1) << ": sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		   		sum2 = 0.0;
		   	}
		   	//cout << bb_to_string(black) << " " << bb_to_string(white) << " " << ev << "\n";
   		}
	    auto end = std::chrono::system_clock::now();       // 計測終了時刻を保存
	    auto dur = end - start;        // 要した時間を計算
	    auto msec = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
	    cout << "\n";
	    //cout << "# total = " << N << "\n";
	    cout << "# dur = " << msec << "msec.\n\n";

   		print_npbw_table();
   	}
   	if( false ) {
   		//	直線パターン・コーナー８個パターン・着手可能箇所数評価値学習
   		Bitboard black, white;
		auto start = std::chrono::system_clock::now();      // 計測スタート時刻
		const int  ITR = 100;
		const int N = 10000;
		const int TOTAL = ITR * N;
		double sum2 = 0;
   		for(int i = 0; i != N; ++i) {
	   		init(black, white);
		   	put_randomly(black, white, 24);	//	24 for 8個空き
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	sum2 += ev * ev;
   		}
   		cout << "0: sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		sum2 = 0;
		vector<int> lst, lst8;
   		for(int i = 0; i != TOTAL; ++i) {
	   		init(black, white);
		   	while( !put_randomly(black, white, 24) ) {	//	24 for 8個空き
		   		init(black, white);
		   	}
		   	double pv = 0.0;	//	パターンによる評価値
		   	get_pat_indexes(black, white, lst);
		   	for(int k = 0; k != lst.size(); ++k) {
		   		pv += g_pat2_val[g_pat_type[k]][lst[k]];
		   	}
		   	get_corner_indexes_hv(black, white, lst8);
		   	for(int k = 0; k != lst8.size(); ++k) {
		   		pv += g_pat8_val[lst8[k]];
		   	}
		   	auto npb = num_place_can_put_black(black, white);
		   	auto npw = num_place_can_put_black(white, black);
			pv += g_npbw_val[npb + npw * (MAX_NP + 1)];
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	//int ev = perfect_game(black, white);
			//cout << "pv = " << pv << ", ev = " << ev << "\n";
		   	auto d = ev - pv;
		   	sum2 += d * d;
		   	d /= 28 * 8;		//	パターン評価値更新値
		   	for(int k = 0; k != lst.size(); ++k) {
		   		auto type = g_pat_type[k];
		   		g_pat2_val[type][lst[k]] += d;
	   			auto ix2 = g_rev_index[lst[k]];
	   			switch( type ) {
	   			case PTYPE_DIAG5: ix2 /= 3;	break;
	   			case PTYPE_DIAG4: ix2 /= 9;	break;
	   			case PTYPE_DIAG3: ix2 /= 27;	break;
	   			}
	   			if( ix2 != lst[k] )
			   		g_pat2_val[type][ix2] += d;
		   		//if( type <= PTYPE_LINE3 || type == PTYPE_DIAG6 ) {
		   		//	if( ix2 != lst[k] )
				//   		g_pat2_val[type][ix2] += d;
		   		//}
		   	}
			vector<int> lst8s;
		   	get_corner_indexes_vh(black, white, lst8s);
		   	for(int k = 0; k != lst8.size(); ++k) {
		   		g_pat8_val[lst8s[k]] = g_pat8_val[lst8[k]] += d;
		   	}
		   	g_npbw_val[npb + npw * (MAX_NP+1)] += d;
		   	if( (i % N) == N - 1 ) {
		   		cout << (i/N+1) << ": sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		   		sum2 = 0.0;
		   	}
		   	//cout << bb_to_string(black) << " " << bb_to_string(white) << " " << ev << "\n";
   		}
	    auto end = std::chrono::system_clock::now();       // 計測終了時刻を保存
	    auto dur = end - start;        // 要した時間を計算
	    auto msec = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
	    cout << "\n";
	    //cout << "# total = " << N << "\n";
	    cout << "# dur = " << msec << "msec.\n\n";

	    cout << "PAT LINE1:\n";
	    print_pat_val(PTYPE_LINE1);
	    cout << "PAT LINE2:\n";
	    print_pat_val(PTYPE_LINE2);
	    cout << "PAT LINE3:\n";
	    print_pat_val(PTYPE_LINE3, true);
	    cout << "PAT DIAG6:\n";
	    print_pat_val(PTYPE_DIAG6, true);
	    //
   		print_npbw_table();
   	}
   	if( false ) {
   		//	直線パターン・コーナー８個パターン・着手可能箇所数・準確定石数評価値学習
   		Bitboard black, white;
		auto start = std::chrono::system_clock::now();      // 計測スタート時刻
		const int  ITR = 30;
		const int N = 10000;
		const int TOTAL = ITR * N;
		g_cnto_slope = 1.0;
		double sum2 = 0;
   		for(int i = 0; i != N; ++i) {
	   		init(black, white);
		   	put_randomly(black, white, 24);	//	24 for 8個空き
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	sum2 += ev * ev;
   		}
   		cout << "0: sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		sum2 = 0;
		vector<int> lst, lst8;
   		for(int i = 0; i != TOTAL; ++i) {
	   		init(black, white);
		   	while( !put_randomly(black, white, 24) ) {	//	24 for 8個空き
		   		init(black, white);
		   	}
#if 0
		   	int npb, npw;	//	着手可能箇所数
		   	int nb, nw;		//	準確定石数
		   	double pv = eval_pat_corner8_ncanput_ncnto(black, white, npb, npw, nb, nw);
#else
		   	double pv = 0.0;	//	パターンによる評価値
		   	get_pat_indexes(black, white, lst);
		   	for(int k = 0; k != lst.size(); ++k) {
		   		pv += g_pat2_val[g_pat_type[k]][lst[k]];
		   	}
		   	get_corner_indexes_hv(black, white, lst8);
		   	for(int k = 0; k != lst8.size(); ++k) {
		   		pv += g_pat8_val[lst8[k]];
		   	}
		   	//	着手可能箇所数
		   	auto npb = num_place_can_put_black(black, white);
		   	auto npw = num_place_can_put_black(white, black);
			pv += g_npbw_val[npb + npw * (MAX_NP + 1)];
			//	準確定石数差
			int nb, nw;
			get_num_cannot_turnover(black, white, nb, nw);
			pv += g_cnto_slope * (nb - nw);
				if( true ) {
			   	int npb, npw;	//	着手可能箇所数
			   	int nb, nw;		//	準確定石数
			   	double pv2 = eval_pat_corner8_ncanput_ncnto(black, white, npb, npw, nb, nw);
			   	assert( pv2 == pv );
			}
#endif
			//
		   	int ev = 0;			//	完全読みによる石差
		   	auto pos = negaAlpha(black, white, ev);
		   	//int ev = perfect_game(black, white);
			//cout << "pv = " << pv << ", ev = " << ev << "\n";
		   	double d = ev - pv;
		   	sum2 += d * d;
		   	d /= 29 * 8;		//	パターン評価値更新値
		   	for(int k = 0; k != lst.size(); ++k) {
		   		auto type = g_pat_type[k];
		   		g_pat2_val[type][lst[k]] += d;
	   			auto ix2 = g_rev_index[lst[k]];
	   			switch( type ) {
	   			case PTYPE_DIAG5: ix2 /= 3;	break;
	   			case PTYPE_DIAG4: ix2 /= 9;	break;
	   			case PTYPE_DIAG3: ix2 /= 27;	break;
	   			}
	   			if( ix2 != lst[k] )
			   		g_pat2_val[type][ix2] += d;
		   		//if( type <= PTYPE_LINE3 || type == PTYPE_DIAG6 ) {
		   		//	if( ix2 != lst[k] )
				//   		g_pat2_val[type][ix2] += d;
		   		//}
		   	}
			vector<int> lst8s;
		   	get_corner_indexes_vh(black, white, lst8s);
		   	for(int k = 0; k != lst8.size(); ++k) {
		   		g_pat8_val[lst8s[k]] = g_pat8_val[lst8[k]] += d;
		   	}
		   	g_npbw_val[npb + npw * (MAX_NP+1)] += d;
		   	if( (i % N) == N - 1 ) {
		   		cout << (i/N+1) << ": sqrt(sum2/N) = " << sqrt(sum2/N) << "\n";
		   		sum2 = 0.0;
		   	}
		   	//cout << bb_to_string(black) << " " << bb_to_string(white) << " " << ev << "\n";
		   	if( nb != nw )
			   	g_cnto_slope += (double)d / (nb - nw);
   		}
	    auto end = std::chrono::system_clock::now();       // 計測終了時刻を保存
	    auto dur = end - start;        // 要した時間を計算
	    auto msec = std::chrono::duration_cast<std::chrono::milliseconds>(dur).count();
	    cout << "\n";
	    //cout << "# total = " << N << "\n";
	    cout << "# dur = " << msec << "msec.\n\n";

	    cout << "PAT LINE1:\n";
	    print_pat_val(PTYPE_LINE1);
	    cout << "PAT LINE2:\n";
	    print_pat_val(PTYPE_LINE2);
	    cout << "PAT LINE3:\n";
	    print_pat_val(PTYPE_LINE3, true);
	    cout << "PAT DIAG6:\n";
	    print_pat_val(PTYPE_DIAG6, true);
	    //
   		print_npbw_table();
   		//
   		cout << "g_cnto_slope = " << g_cnto_slope << "\n";
   	}
   	if( false ) {
   		//	スキャンテスト
   		Bitboard black = 0x050d072c0700;		//	8個空き
   		Bitboard white = 0x38303810083c;
   		//Bitboard black = 0x042910080c3e;		//	8個空き
   		//Bitboard white = 0x32140f173000;
   		//Bitboard black = 0x070f050b013e;		//	2個空き
   		//Bitboard white = 0x38303a143e00;
   		print(black, white);
   		Bitboard cnto_h = 0;
   		for(int y = 0; y != N_VERT; ++y) {
   			cnto_h |= scan_cannot_turnover_shr(black, white, xyToBit(0, y), DIR_L);
   		}
   		cout << "h: " << bb_to_string(cnto_h) << "\n";
   		Bitboard cnto_v = 0;
   		for(int x = 0; x != N_HORZ; ++x) {
   			cnto_v |= scan_cannot_turnover_shr(black, white, xyToBit(x, 0), DIR_U);
   		}
   		cout << "v: " << bb_to_string(cnto_v) << "\n";
   		Bitboard cnto_sl = 0x302000000103;		//	／方向
   		for(int x = 2; x != N_HORZ; ++x) {
   			cnto_sl |= scan_cannot_turnover_shr(black, white, xyToBit(x, 0), DIR_UR);
   		}
   		for(int y = 1; y != N_HORZ-2; ++y) {
   			cnto_sl |= scan_cannot_turnover_shr(black, white, xyToBit(N_HORZ-1, y), DIR_UR);
   		}
   		cout << "s: " << bb_to_string(cnto_sl) << "\n";
   		Bitboard cnto_bs = 0x030100002030;		//	＼方向
   		for(int x = N_HORZ-2; --x >= 0; ) {
   			cnto_bs |= scan_cannot_turnover_shr(black, white, xyToBit(x, 0), DIR_UL);
   		}
   		for(int y = 1; y != N_HORZ-2; ++y) {
   			cnto_bs |= scan_cannot_turnover_shr(black, white, xyToBit(0, y), DIR_UL);
   		}
   		cout <<"b: " << bb_to_string(cnto_bs) << "\n";
   		cout << "\n";
   		cout << "black = " << bb_to_string(black & cnto_h & cnto_v & cnto_sl & cnto_bs) << "\n";
   		cout << "white = " << bb_to_string(white & cnto_h & cnto_v & cnto_sl & cnto_bs) << "\n";
   		int nb, nw;
   		get_num_cannot_turnover(black, white, nb, nw);
   		//cout << "nb = " << nb << ", nw = " << nw << "\n";
   		cout << "nb = " << nb << ", nw = " << nw << ", diff = " << (nb - nw) << "\n";
	   	int ev = 0;
	   	auto pos = negaAlpha(black, white, ev);
	   	cout << "ev = " << ev << "\n";
   	}
   	if( false ) {
   		//	スキャンテスト
   		Bitboard black, white;
   		init(black, white);
	   	put_randomly(black, white, 24);	//	24 for 8個空き
   		cout << "black = " << bb_to_string(black) << "\n";
   		cout << "white = " << bb_to_string(white) << "\n";
   		print(black, white);
   		Bitboard cnto_h = 0;
   		for(int y = 0; y != N_VERT; ++y) {
   			cnto_h |= scan_cannot_turnover_shr(black, white, xyToBit(0, y), DIR_L);
   		}
   		cout << bb_to_string(cnto_h) << "\n";
   		Bitboard cnto_v = 0;
   		for(int x = 0; x != N_HORZ; ++x) {
   			cnto_v |= scan_cannot_turnover_shr(black, white, xyToBit(x, 0), DIR_U);
   		}
   		cout << bb_to_string(cnto_v) << "\n";
   		Bitboard cnto_sl = 0x308000000103;		//	／方向
   		for(int x = 2; x != N_HORZ; ++x) {
   			cnto_sl |= scan_cannot_turnover_shr(black, white, xyToBit(x, 0), DIR_UR);
   		}
   		for(int y = 1; y != N_HORZ-2; ++y) {
   			cnto_sl |= scan_cannot_turnover_shr(black, white, xyToBit(N_HORZ-1, y), DIR_UR);
   		}
   		cout << bb_to_string(cnto_sl) << "\n";
   		Bitboard cnto_bs = 0x030100002030;		//	＼方向
   		for(int x = N_HORZ-2; --x >= 0; ) {
   			cnto_bs |= scan_cannot_turnover_shr(black, white, xyToBit(x, 0), DIR_UL);
   		}
   		for(int y = 1; y != N_HORZ-2; ++y) {
   			cnto_bs |= scan_cannot_turnover_shr(black, white, xyToBit(0, y), DIR_UL);
   		}
   		cout << bb_to_string(cnto_bs) << "\n";
   		cout << "\n";
   		cout << "black = " << bb_to_string(black & cnto_h & cnto_v & cnto_sl & cnto_bs) << "\n";
   		cout << "white = " << bb_to_string(white & cnto_h & cnto_v & cnto_sl & cnto_bs) << "\n";
   		int nb, nw;
   		get_num_cannot_turnover(black, white, nb, nw);
   		cout << "nb = " << nb << ", nw = " << nw << ", diff = " << (nb - nw) << "\n";
	   	int ev = 0;
	   	auto pos = negaAlpha(black, white, ev);
	   	cout << "ev = " << ev << "\n";
   	}
   	if( false ) {
   		//	スキャンテスト
   		Bitboard black, white;
   		for(int i = 0; i != 100; ++i) {
	   		init(black, white);
		   	//put_randomly(black, white, 24);	//	24 for 8個空き
		   	put_randomly(black, white, 28);	//	28 for 4個空き
	   		int nb, nw;
	   		get_num_cannot_turnover(black, white, nb, nw);
	   		//cout << "nb = " << nb << ", nw = " << nw << ", diff = " << (nb - nw) << "\n";
		   	int ev = 0;
		   	auto pos = negaAlpha(black, white, ev);
		   	cout << (nb-nw) << ", " << ev << "\n";
   		}
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
   	if( false ) {
   		ML ml;		//	機械学習オブジェクト
   		//ml.print_pat_vals();
   		Bitboard black, white;
   		init(black, white);
	   	put_randomly(black, white, 24);	//	24 for 8個空き
   		print(black, white);
	   	int alpha = 0;
	   	auto pos = negaAlpha(black, white, alpha);
	   	ml.learn_pat_vals(black, white, alpha);
   		ml.print_pat_vals();

   	}
   	if( false ) {
   		ML ml;		//	機械学習オブジェクト
   		Bitboard black, white;
		const int  ITR = 20;
		const int N = 10000;
		const int TOTAL = ITR * N;
   		for(int i = 0; i != TOTAL; ++i) {
	   		init(black, white);
		   	while( !put_randomly(black, white, 24) ) {	//	24 for 8個空き
		   		init(black, white);
		   	}
		   	int alpha = 0;
		   	auto pos = negaAlpha(black, white, alpha);
		   	ml.learn_pat_vals(black, white, alpha);		//	全位置共通パターン評価値学習
		   	if( (i % N) == N - 1 ) {
		   		cout << (i/N+1) << ": sqrt(err2/N) = " << sqrt(ml.get_err2()/N) << "\n";
		   		ml.clear_round_err2();
		   	}
   		}
   		//	学習結果評価用データ出力
   		for(int i = 0; i != 100; ++i) {
	   		init(black, white);
		   	while( !put_randomly(black, white, 24) ) {	//	24 for 8個空き
		   		init(black, white);
		   	}
		   	int alpha = 0;
		   	auto pos = negaAlpha(black, white, alpha);
		   	auto ev = ml.ev_pat_vals(black, white);
		   	cout << ev << ", " << alpha << "\n";
   		}
   	}
   	if( true ) {
   		ML ml;		//	機械学習オブジェクト
   		Bitboard black, white;
		const int  ITR = 20;
		const int N = 10000;
		const int TOTAL = ITR * N;
   		for(int i = 0; i != TOTAL; ++i) {
	   		init(black, white);
		   	while( !put_randomly(black, white, 24) ) {	//	24 for 8個空き
		   		init(black, white);
		   	}
		   	int alpha = 0;
		   	auto pos = negaAlpha(black, white, alpha);
		   	ml.learn_pat2_vals(black, white, alpha);		//	位置ごとパターン評価値学習
		   	if( (i % N) == N - 1 ) {
		   		cout << (i/N+1) << ": sqrt(err2/N) = " << sqrt(ml.get_err2()/N) << "\n";
		   		ml.clear_round_err2();
		   	}
   		}
   		//	学習結果評価用データ出力
   		for(int i = 0; i != 100; ++i) {
	   		init(black, white);
		   	while( !put_randomly(black, white, 24) ) {	//	24 for 8個空き
		   		init(black, white);
		   	}
		   	int alpha = 0;
		   	auto pos = negaAlpha(black, white, alpha);
		   	auto ev = ml.ev_pat2_vals(black, white);
		   	cout << ev << ", " << alpha << "\n";
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
bool put_randomly(Bitboard &black, Bitboard &white, int depth, bool passed) {
	if( depth == 0 ) {		//	末端局面
		//print(black, white);
		return true;
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
			return put_randomly(white, black, depth, true);
		} else {			//	１手前がパス → 双方パスで終局
			//print(black, white);
			return false;
		}
	} else {
		int ix = (g_mt() % (lst.size()/2)) * 2;		//	ランダムに着手を選ぶ
		auto b = lst[ix];
		auto rev = lst[ix + 1];
		black |= b | rev;
		white ^= rev;
		return put_randomly(white, black, depth - 1);
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
//	着手可能箇所数評価値テーブル値表示
void print_npbw_table() {
	for(int y = 0; y <= MAX_NP; ++y) {
		for(int x = 0; x <= MAX_NP; ++x) {
			auto t = double2string(g_npbw_val[x + y * (MAX_NP+1)]);
			cout << t << " ";
		}
		cout << "\n";
	}
	cout << "\n";
}
//	パターン評価値テーブル値表示
void print_pat_val(int type, bool center) {		//	center: 3, 4 番目は空でないこと
    string pat;
    for(int i = 0; i != N_PAT; ++i) {
    	auto val = to_string(g_pat2_val[type][i]);
    	indexToPat(i, pat);
    	if( val[0] != '-' ) val = ' ' + val;
    	if( center && (pat[2] == '.' || pat[3] == '.') )
			val = "   N/A   ";
    	cout << pat << ": " << val << "\t";
    	if( ((i+1) % 3) == 0 ) cout << "\n";
    }
    cout << "\n";
}
