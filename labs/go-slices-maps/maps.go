package main

import (
	"golang.org/x/tour/wc"
	"strings"
)

func WordCount(s string) map[string]int {
	words := strings.Split(s," ")
	wordCounter := map[string]int{}
	for _,word := range words{
		wordCounter[word]++
	}
	return wordCounter
}

func main() {
	wc.Test(WordCount)
}