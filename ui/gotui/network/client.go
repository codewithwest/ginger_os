package network

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/gorilla/websocket"
)

const baseURL = "http://localhost:8087"
const wsBaseURL = "ws://localhost:8087"

type LogMsg struct {
	Msg   string `json:"msg"`
	Style string `json:"style"`
}

type ChatMsg struct {
	Status  string   `json:"status"`
	Msg     string   `json:"msg"`
	Answer  string   `json:"answer"`
	Sources []string `json:"sources"`
}

type SystemStatusMsg struct {
	Status string `json:"status"`
	// Additional fields like cpu, steps, etc. can be unmarshaled here
	Raw json.RawMessage
}

// SubscribeToLogs connects to the logs websocket and returns a tea.Cmd that
// waits for the next message.
func SubscribeToLogs() tea.Cmd {
	return func() tea.Msg {
		conn, _, err := websocket.DefaultDialer.Dial(wsBaseURL+"/ws/logs", nil)
		if err != nil {
			time.Sleep(2 * time.Second)
			return ErrorMsg{err}
		}
		defer conn.Close()

		// Read loop for a single message to fit into tea.Cmd pattern
		// But usually websockets are better handled via a continuous goroutine 
		// that sends to a channel, and a tea.Cmd that reads from the channel.
		
		// For simplicity in a pure Cmd architecture, we return a function that returns a sub-Cmd
		_, msg, err := conn.ReadMessage()
		if err != nil {
			return ErrorMsg{err}
		}

		var logData LogMsg
		if err := json.Unmarshal(msg, &logData); err != nil {
			return ErrorMsg{err}
		}
		
		// Note: To keep the connection open, this approach requires passing the conn around.
		// A better architecture is a global channel.
		return logData
	}
}

// We define a global channel for logs
var LogChannel = make(chan LogMsg, 100)

func StartLogListener() {
	go func() {
		for {
			conn, _, err := websocket.DefaultDialer.Dial(wsBaseURL+"/ws/logs", nil)
			if err != nil {
				time.Sleep(2 * time.Second)
				continue
			}

			for {
				_, msg, err := conn.ReadMessage()
				if err != nil {
					break // Connection lost, retry
				}

				var logData LogMsg
				if err := json.Unmarshal(msg, &logData); err == nil {
					LogChannel <- logData
				}
			}
			conn.Close()
		}
	}()
}

// WaitForLog is a Cmd that reads the next message from the channel
func WaitForLog() tea.Msg {
	return <-LogChannel
}

// FetchStatus retrieves the /api/status endpoint
func FetchStatus() tea.Cmd {
	return func() tea.Msg {
		client := http.Client{Timeout: 5 * time.Second}
		resp, err := client.Get(baseURL + "/api/status")
		if err != nil {
			return ErrorMsg{err}
		}
		defer resp.Body.Close()

		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return ErrorMsg{err}
		}

		var status SystemStatusMsg
		status.Raw = body
		return status
	}
}

type ErrorMsg struct {
	Err error
}

func (e ErrorMsg) Error() string {
	return fmt.Sprintf("network error: %v", e.Err)
}

// RunStep triggers a step execution
func RunStep(idx int) tea.Cmd {
	return func() tea.Msg {
		client := http.Client{Timeout: 5 * time.Second}
		url := fmt.Sprintf("%s/api/step/%d/run", baseURL, idx)
		resp, err := client.Post(url, "application/json", nil)
		if err != nil {
			return ErrorMsg{err}
		}
		defer resp.Body.Close()
		return nil
	}
}

// ForceStep forces a step execution
func ForceStep(idx int) tea.Cmd {
	return func() tea.Msg {
		client := http.Client{Timeout: 5 * time.Second}
		url := fmt.Sprintf("%s/api/step/%d/force", baseURL, idx)
		resp, err := client.Post(url, "application/json", nil)
		if err != nil {
			return ErrorMsg{err}
		}
		defer resp.Body.Close()
		return nil
	}
}

// ControlAction triggers auto, abort, resume actions
func ControlAction(action string) tea.Cmd {
	return func() tea.Msg {
		client := http.Client{Timeout: 5 * time.Second}
		url := fmt.Sprintf("%s/api/control/%s", baseURL, action)
		resp, err := client.Post(url, "application/json", nil)
		if err != nil {
			return ErrorMsg{err}
		}
		defer resp.Body.Close()
		return nil
	}
}

// TakeSnapshot creates a snapshot
func TakeSnapshot(label string) tea.Cmd {
	return func() tea.Msg {
		client := http.Client{Timeout: 5 * time.Second}
		url := fmt.Sprintf("%s/api/snapshots/take?label=%s", baseURL, label)
		resp, err := client.Post(url, "application/json", nil)
		if err != nil {
			return ErrorMsg{err}
		}
		defer resp.Body.Close()
		return nil
	}
}
