#include <iostream>
#include "BoardIndex.h"

using namespace std;

int main()
{
	BoardIndex bd;
	bd.print();
	//
	buildIndexTable();
	//
	for(int y = 0; y != N_VERT; ++y) {
		for(int x = 0; x != N_HORZ; ++x ) {
			cout << (bd.can_put_black(x, y) ? "+" : "-");
		}
		cout << "\n";
	}
    std::cout << "\nOK.\n";
}
