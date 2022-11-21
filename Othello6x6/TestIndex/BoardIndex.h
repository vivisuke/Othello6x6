#pragma once

#include <vector>

typedef unsigned char uchar;
typedef unsigned short ushort;

#define		EMPTY			0
#define		BLACK			1
#define		WHITE			2
#define		WALL			3

#define		N_VERT			4
#define		N_HORZ			4
#define		N_IX_HORZ		N_VERT				//	水平方向
#define		N_IX_VERT		N_HORZ				//	垂直方向
#if N_HORZ == 4
	#define		N_IX_UL_BR		3					//	＼方向 インデックス数
	#define		N_IX_BL_UR		3					//	／方向
	#define		IX_TABLE_SIZE	(3*3*3*3)		//	3^4
#else
	#define		N_IX_UL_BR		7					//	＼方向
	#define		N_IX_BL_UR		7					//	／方向
	#define		IX_TABLE_SIZE	(3*3*3*3*3*3)		//	3^6
#endif

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

ushort patWToIndex(const std::vector<uchar> &lst);		//	前後に壁がある版
void indexToPatW(ushort index, std::vector<uchar> &lst, int len = N_HORZ);		//	前後に壁を配置する版
ushort patToIndex(const std::vector<uchar> &lst);
void indexToPat(ushort index, std::string &lst, int len = N_HORZ);
void indexToPat(ushort index, std::vector<uchar> &lst, int len = N_HORZ);
void indexToPat(ushort index, uchar *ptr, int len = 6);
void buildIndexTable();
std::string patWtoString(std::vector<uchar> &);

class BoardIndex
{
public:
	BoardIndex() { init(); }
public:
	void	init();
	//void	buildIndexTable();
	void	print() const;
	void	print_vert() const;			//	縦インデックス表示
	void	print_diagonal() const;		//	斜めインデックス表示
	void	print_diagonal2() const;		//	斜めインデックス表示
	bool	can_put_black(int x, int y) const;
	bool	can_put_white(int x, int y) const;
public:
	void	put_black(int x, int y);
	void	put_white(int x, int y);
//private:
public:
	//	盤面状態
	ushort	m_ix_horz[N_IX_HORZ];
	ushort	m_ix_vert[N_IX_VERT];
	ushort	m_ix_bl_ur[N_IX_BL_UR];		//	／方向
	ushort	m_ix_ul_br[N_IX_UL_BR];		//	＼方向
};

