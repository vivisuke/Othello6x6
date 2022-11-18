#pragma once

#include <vector>

typedef unsigned char uchar;
typedef unsigned short ushort;

#define		EMPTY			0
#define		BLACK			1
#define		WHITE			2

#define		N_VERT			4
#define		N_HORZ			4
#define		N_IX_HORZ		N_VERT				//	水平方向
#define		N_IX_VERT		N_HORZ				//	垂直方向
#define		N_IX_UL_BR		7					//	＼方向
#define		N_IX_BL_UR		7					//	／方向
#define		IX_TABLE_SIZE	(3*3*3*3*3*3)		//	3^6

/*

インデックス：
	パターン配列の若い番地から 3^0, 3^1, 3^2, ... 3^5 とする



m_ix_ul_br：

      ix = 0
        ↓
　ａｂｃｄｅｆ
１・・／／／／←ix = 3
２・／／／／／←ix = 4
３／／／／／／←ix = 5
４／／／／／／←ix = 6
５／／／／／・
６／／／／・・

m_ix_bl_ur：

　ａｂｃｄｅｆ
１＼＼＼＼・・
２＼＼＼＼＼・
３＼＼＼＼＼＼←ix = 6
４＼＼＼＼＼＼←ix = 5
５・＼＼＼＼＼←ix = 4
６・・＼＼＼＼←ix = 3
       ↑
     ix = 0

*/

ushort patToIndex(const std::vector<uchar> &lst);
void indexToPat(ushort index, std::string &lst, int len = 6);
void indexToPat(ushort index, std::vector<uchar> &lst, int len = 6);
void indexToPat(ushort index, uchar *ptr, int len = 6);
void buildIndexTable();

class BoardIndex
{
public:
	BoardIndex() { init(); }
public:
	void	init();
	void	print() const;
//private:
public:
	//	盤面状態
	ushort	m_ix_horz[N_IX_HORZ];
	ushort	m_ix_vert[N_IX_VERT];
	ushort	m_ix_bl_ur[N_IX_BL_UR];
	ushort	m_ix_ul_br[N_IX_UL_BR];
	//	状態遷移先インデックステーブル
	short	m_put_black_ix[N_HORZ];		//	黒を打った場合の遷移先インデックス
	short	m_put_white_ix[N_HORZ];		//	白を打った場合の遷移先インデックス
};

