package main

import "golang.org/x/tour/pic"

func Pic(dx, dy int) [][]uint8 {
	sy := make([][]uint8, dy)
	for y := range sy {
		sx := make([]uint8, dx)
		for x := range sx {
			sx[x] = uint8(x ^ y)
		}
		sy[y] = sx
	}
	return sy
}

func main() {
	pic.Show(Pic)
}
