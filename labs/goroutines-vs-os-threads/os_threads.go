//found limit of ~ 2.5 mio goroutines with 8GB Memory
package main

import (
	"fmt"
	"time"
)

const stages = 100

func main() {
	input := make(chan int)
	output := make(chan int)
	for inputAt := time.Now(); time.Since(inputAt) < time.Second; {
		go pass(input, output)
		go pass(output, input)
	}
	input <- 1
	select {
	case messages := <-input:
		fmt.Println("Number of messages:", messages)
	case messages := <-output:
		fmt.Println("Number of messages:", messages)
	}
	close(input)
	close(output)
}

func pass(input chan int, output chan int) {
	for val := range input {
		val++
		output <- val
	}
}
