package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"
)

func stage(input chan int, output chan int) {
	val := <-input
	val++
	output <- val
}

func main() {
	numberStages, err := strconv.Atoi(os.Args[1])
	if err != nil {
		log.Fatal("Missing argument number of stages")
	}
	in := make(chan int)
	a := in
	b := make(chan int)
	for i := 1; i < numberStages; i++ {
		go stage(a, b)
		a = b
		b = make(chan int)
		if i%100000 == 0 {
			fmt.Println(i)
		}
	}
	out := a
	started := time.Now()
	in <- 1
	v := <-out
	elapsed := time.Since(started)
	txtLines := getLines("go_routines.txt")
	txtLines = append(txtLines, strconv.Itoa(v)+" took "+elapsed.String())
	writeFile("go_routines.txt", txtLines)
}

func getLines(name string) []string {

	fmt.Println("Opening file: " + name)

	file, err := os.Open(name)
	if err != nil {
		log.Fatalf("failed opening file: %s", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	scanner.Split(bufio.ScanLines)
	var txtlines []string

	for scanner.Scan() {
		txtlines = append(txtlines, scanner.Text())
	}

	return txtlines
}

func writeFile(name string, txtLines []string) {

	f, err := os.Create(name)
	defer f.Close()
	if err != nil {
		log.Fatalf("failed writing file: %s", err)
	}

	w := bufio.NewWriter(f)
	defer w.Flush()
	for _, line := range txtLines {
		_, err = w.WriteString(line + "\n")
		if err != nil {
			log.Fatalf("failed writing file: %s", err)
		}
	}
}
