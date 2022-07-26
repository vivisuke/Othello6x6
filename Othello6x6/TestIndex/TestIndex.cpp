﻿#include <iostream>
#include "BoardIndex.h"

using namespace std;

int main()
{
	BoardIndex bd;
	bd.print();
	bd.print_vert();
	bd.print_diagonal();
	bd.print_diagonal2();
	//
	buildIndexTable();
	//
	for(int y = 0; y != N_VERT; ++y) {
		for(int x = 0; x != N_HORZ; ++x ) {
			cout << (bd.can_put_black(x, y) ? "+" : "-");
		}
		cout << "\n";
	}
	cout << "\n";
	//
	int x = 0, y = 1;		//	a2
	cout << "put_black(" << x << ", " << y << "):\n";
	bd.put_black(x, y);
	bd.print();
	bd.print_vert();
	bd.print_diagonal();
	bd.print_diagonal2();
	//
	for(int y = 0; y != N_VERT; ++y) {
		for(int x = 0; x != N_HORZ; ++x ) {
			cout << (bd.can_put_white(x, y) ? "+" : "-");
		}
		cout << "\n";
	}
	cout << "\n";
	//
#if 0
	x = 2; y = 0;		//	c1
	cout << "put_white(" << x << ", " << y << "):\n";
	bd.put_white(x, y);
	bd.print();
	bd.print_vert();
	//
	for(int y = 0; y != N_VERT; ++y) {
		for(int x = 0; x != N_HORZ; ++x ) {
			cout << (bd.can_put_black(x, y) ? "+" : "-");
		}
		cout << "\n";
	}
	cout << "\n";
	//
#endif
    std::cout << "\nOK.\n";
}
