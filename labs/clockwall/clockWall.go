// Netcat1 is a read-only TCP client.
package main

import (
	"io"
	"log"
	"net"
	"os"
	"strings"
)

func mustCopy(dst io.Writer, src io.Reader) {
	if _, err := io.Copy(dst, src); err != nil {
		log.Fatal(err)
	}
}

func main() {
	args := os.Args[1:]
	for _, arg := range args {
		port := strings.Split(arg, "=")[1]
		dialPort(port)
	}
	//clockWall NewYork=localhost:8010 Tokyo=localhost:8020 London=localhost:8030
}

func dialPort(port string) {
	conn, err := net.Dial("tcp", port)
	if err != nil {
		log.Fatal(err)
	}
	defer conn.Close()
	mustCopy(os.Stdout, conn)
}
