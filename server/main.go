package main

import (
	"encoding/json"
	"flag"
	"log"
	"net/http"

	guuid "github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/gorilla/websocket"
)

var addr = flag.String("addr", ":3001", "http service address")

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin:     func(r *http.Request) bool { return true },
}

type Client struct {
	id   string
	conn *websocket.Conn
}

var streamer *websocket.Conn
var clients = make(map[string]*Client)

func main() {
	flag.Parse()

	r := mux.NewRouter()
	r.HandleFunc("/stream", func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Println(err)
			return
		}
		defer conn.Close()
		defer func() {
			if streamer != nil {
				streamer.Close()
				streamer = nil
			}
		}()

		if streamer == nil {
			for {
				streamer = conn
				_, msg, err := conn.ReadMessage()
				if err != nil {
					log.Println(err)
					return
				}
				var data map[string]interface{}
				err = json.Unmarshal(msg, &data)
				if err != nil {
					log.Println(err)
					return
				}

				// handle offer
				if data["offer"] != nil {

					clients[data["to"].(string)].conn.WriteMessage(websocket.TextMessage, msg)
				}

				if data["answer"] != nil {
					clients[data["to"].(string)].conn.WriteMessage(websocket.TextMessage, msg)
				}

				// handle candidate
				if data["ice"] != nil {
					clients[data["to"].(string)].conn.WriteMessage(websocket.TextMessage, msg)
				}
			}
		}
	})

	r.HandleFunc("/watch", func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		id := guuid.New().String()
		if err != nil {
			log.Println(err)
			return
		}
		defer conn.Close()
		defer func() {
			if clients[id].conn != nil {
				clients[id].conn.Close()
				delete(clients, id)
			}
		}()

		client := Client{
			id:   id,
			conn: conn,
		}

		clients[id] = &client

		for {
			_, msg, err := conn.ReadMessage()
			if err != nil {
				log.Println(err)
				return
			}
			var data map[string]interface{}
			err = json.Unmarshal(msg, &data)
			if err != nil {
				log.Println(err)
				return
			}

			if data["join"] != nil {
				res, _ := json.Marshal(map[string]interface{}{
					"joined": id,
				})
				conn.WriteMessage(websocket.TextMessage, res)
			}
			if data["offer"] != nil {
				streamer.WriteMessage(websocket.TextMessage, msg)
			}

			if data["answer"] != nil {
				streamer.WriteMessage(websocket.TextMessage, msg)
			}

			if data["ice"] != nil {
				streamer.WriteMessage(websocket.TextMessage, msg)
			}
		}
	})
	log.Default().Println("Server started at", *addr)

	if err := http.ListenAndServe(*addr, r); err != nil {
		log.Fatal("ListenAndServe: ", err)
	}
}
