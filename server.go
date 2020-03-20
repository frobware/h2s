package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"

	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
)

const (
	defaultH2Port  = "8443"
	defaultH2CPort = "8080"
)

func handler(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	// h2spec only requires that we handle GET and POST.

	switch r.Method {
	case "GET":
		for k, v := range r.URL.Query() {
			log.Printf("%s: %s\n", k, v)
		}
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte("Received a GET request\n"))
		w.Write([]byte(strings.Repeat("Here's some data.", 1024)))
	case "POST":
		reqBody, err := ioutil.ReadAll(r.Body)
		if err != nil {
			log.Printf("ReadAll error: %v\n", err)
			return
		}
		defer r.Body.Close()
		log.Printf("Request Body: %q\n", reqBody)
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte("Received a POST request\n"))
	default:
		w.WriteHeader(http.StatusNotImplemented)
		w.Write([]byte(http.StatusText(http.StatusNotImplemented)))
	}

}

func lookupEnv(key, defaultVal string) string {
	if val, ok := os.LookupEnv(key); ok {
		return val
	}
	return defaultVal
}

func main() {
	http.HandleFunc("/", handler)

	h2Addr := fmt.Sprintf(":%s", lookupEnv("H2PORT", defaultH2Port))
	h2cAddr := fmt.Sprintf(":%s", lookupEnv("H2CPORT", defaultH2CPort))

	go func() {
		// H2C Server
		server := &http.Server{
			Addr: h2cAddr,
			Handler: h2c.NewHandler(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				handler(w, r)
			}), &http2.Server{}),
		}

		if err := server.ListenAndServe(); err != nil {
			log.Fatal("ListenAndServe: ", err)
		}
	}()

	go func() {
		// H2 Server
		err := http.ListenAndServeTLS(h2Addr, "/etc/service-certs/tls.crt", "/etc/service-certs/tls.key", nil)

		if err != nil {
			log.Fatal("ListenAndServeTLS: ", err)
		}
	}()

	log.Printf("ListenAndServe: %s\n", h2cAddr)
	log.Printf("ListenAndServeTLS: %s\n", h2Addr)

	select {}
}
