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
	start := make(chan int)
	var end chan int
	lastOutput := start
	numberStages := 1400000

	for i := 0; i < numberStages; i++ {
		newOutput := make(chan int)
		go stage(lastOutput, newOutput)
		lastOutput = newOutput
		if i %100000 == 0{
			fmt.Println(i)
		}
		if i == numberStages-1 {
			end = newOutput
		}
	}
	begin := time.Now()
	start <- 0
	elapsed := time.Since(begin)
	txtLines := getLines("output.txt")
	txtLines = append(txtLines, strconv.Itoa(<-end)+" took "+elapsed.String())
	writeFile("output.txt", txtLines)
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
