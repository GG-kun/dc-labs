package main

import (
	"encoding/xml"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"strings"
)

var bucketURL string

type content struct {
	Key string `xml:"Key"`
}

type bucket struct {
	Name     string    `xml:"Name"`
	Contents []content `xml:"Contents"`
}

type bucketData struct {
	Name       string
	NumberDir  int
	Extensions map[string]int
}

func init() {
	flag.StringVar(&bucketURL, "bucket", "", "Bucket name of AWS")
	flag.Parse()
}

func main() {
	result := bucket{}

	if xmlBytes, err := getXML(bucketURL); err != nil {
		log.Printf("Failed to get XML: %v", err)
	} else {
		xml.Unmarshal(xmlBytes, &result)
	}

	data := result.getData()
	data.printData()
}

func getXML(url string) ([]byte, error) {
	response, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("GET error: %v", err)
	}
	defer response.Body.Close()

	data, err := ioutil.ReadAll(response.Body)
	if err != nil {
		return nil, fmt.Errorf("Read body: %v", err)
	}

	return data, nil
}

func (b *bucket) getData() bucketData {
	extensions := map[string]int{}
	directories := []string{}
	for _, c := range b.Contents {
		k := strings.Split(c.Key, "/")
		if len(k) > 1 {
			f := strings.Split(k[len(k)-1], ".")
			if len(f) <= 1 {
				directories = append(directories, c.Key)
			} else {
				extensions[f[len(f)-1]]++
			}
		}
	}

	return bucketData{b.Name, len(directories), extensions}
}

func (b *bucketData) printData() {
	noObjs := 0
	for _, value := range b.Extensions {
		noObjs += value
	}
	fmt.Print("AWS S3 Explorer\nBucket Name\t\t: ", b.Name, "\nNumber of objects\t: ", noObjs, "\nNumber of directories\t: ", b.NumberDir, "\nExtensions\t\t: ")
	i := 0
	for key, value := range b.Extensions {
		i++
		fmt.Print(key, "(", value, ")")
		if i != len(b.Extensions) {
			fmt.Print(",")
		}
	}
}
