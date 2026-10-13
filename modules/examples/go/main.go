package main

import (
	"bufio"
	"encoding/json"
	"os"
)

func main() {
	encoder := json.NewEncoder(os.Stdout)
	encoder.Encode(map[string]any{"type": "ready", "protocol": 1})
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 4096), 65537)
	gain := 2.0
	for scanner.Scan() {
		var message struct {
			Type string `json:"type"`
			Port string `json:"port"`
			Value float64 `json:"value"`
			Hops int `json:"hops"`
			Parameters map[string]float64 `json:"parameters"`
			Values map[string]float64 `json:"values"`
		}
		if json.Unmarshal(scanner.Bytes(), &message) != nil { return }
		switch message.Type {
		case "init", "parameters":
			values := message.Parameters
			if message.Type == "parameters" { values = message.Values }
			if value, ok := values["gain"]; ok { gain = value }
		case "input":
			if message.Port != "input" { continue }
			result := message.Value * gain
			encoder.Encode(map[string]any{"type": "state", "values": map[string]any{"result": result}})
			encoder.Encode(map[string]any{"type": "output", "port": "output", "value": result, "hops": message.Hops})
		}
	}
}
