#include <iostream>
#include <assert.h>
#include "BoardArray.h"

using namespace std;

int main()
{
    BoardArray ba;
    ba.print();
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

    std::cout << "\nOK.\n";
}
