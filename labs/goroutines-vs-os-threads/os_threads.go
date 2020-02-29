//found limit of ~ 2.5 mio goroutines with 8GB Memory
package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"
)

func main() {
	input := make(chan int)
	output := make(chan int)
	for inputAt := time.Now(); time.Since(inputAt) < time.Second; {
		go pass(input, output)
		go pass(output, input)
	}
	input <- 1
	messages := 0
	select {
	case messages = <-input:
		fmt.Println("Number of messages:", messages)
	case messages = <-output:
		fmt.Println("Number of messages:", messages)
	}
	close(input)
	close(output)
	txtLines := getLines("os_threads.txt")
	txtLines = append(txtLines, "Number of messages: "+strconv.Itoa(messages))
	writeFile("os_threads.txt", txtLines)
}

func pass(input chan int, output chan int) {
	for val := range input {
		val++
		output <- val
	}
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
