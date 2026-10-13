package main

import (
 "bufio"
 "crypto/sha256"
 "encoding/hex"
 "encoding/json"
 "os"
)

func main() {
 encoder := json.NewEncoder(os.Stdout)
 encoder.Encode(map[string]any{"type":"ready", "protocol":1})
 scanner := bufio.NewScanner(os.Stdin)
 scanner.Buffer(make([]byte, 4096), 65537)
 calls := 0
 for scanner.Scan() {
  var message struct {
   Type string `json:"type"`
   Port string `json:"port"`
   Value map[string]any `json:"value"`
   Hops int `json:"hops"`
  }
  if json.Unmarshal(scanner.Bytes(), &message) != nil { return }
  if message.Type != "input" || message.Port != "input" { continue }
  canonical, err := json.Marshal(message.Value)
  if err != nil { return }
  digest := sha256.Sum256(canonical)
  calls++
  result := map[string]any{"digest":hex.EncodeToString(digest[:]), "calls":calls, "received":message.Value}
  encoder.Encode(map[string]any{"type":"state", "values":map[string]any{"result":result}})
  encoder.Encode(map[string]any{"type":"output", "port":"output", "value":result, "hops":message.Hops})
 }
}
