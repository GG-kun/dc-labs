// Clock2 is a concurrent TCP server that periodically writes the time.
package main

import (
	"flag"
	"io"
	"log"
	"net"
	"os"
	"strings"
	"time"
)

func handleConn(c net.Conn, name string) {
	defer c.Close()
	t, err := timeIn(time.Now(), name)
	if err != nil {
		return // e.g., client disconnected
	}
	_, err = io.WriteString(c, t.Format("15:04:05\n"))
	if err != nil {
		return // e.g., client disconnected
	}
	time.Sleep(1 * time.Second)
}

func main() {

	var port = flag.String("port", "", "")
	flag.Parse()
	listenerPort(strings.Replace(os.Getenv("TZ"), "-", "/", -1), *port)

	/*TZ=US-Eastern    ./clock2 -port 8010 &
	TZ=Asia-Tokyo    ./clock2 -port 8020 &
	TZ=Europe-London ./clock2 -port 8030 &*/
}

func listenerPort(name, port string) {
	listener, err := net.Listen("tcp", "localhost:"+port)
	if err != nil {
		log.Fatal(err)
	}
	for {
		conn, err := listener.Accept()
		if err != nil {
			log.Print(err) // e.g., connection aborted
			continue
		}
		go handleConn(conn, name) // handle connections concurrently
	}
}

func timeIn(t time.Time, name string) (time.Time, error) {
	loc, err := time.LoadLocation(name)
	if err == nil {
		t = t.In(loc)
	}
	return t, err
}
