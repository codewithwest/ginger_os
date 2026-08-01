package network

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
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
	Raw    json.RawMessage
}

type ConnectionStatusMsg struct {
	Connected bool
}

type LogChannelFullMsg struct{}

var (
	LogChannel    = make(chan LogMsg, 100)
	wsCtx, wsCancel = context.WithCancel(context.Background())
)

func StopLogListener() {
	wsCancel()
}

func StartLogListener() {
	go func() {
		for {
			select {
			case <-wsCtx.Done():
				return
			default:
			}

			conn, _, err := websocket.DefaultDialer.Dial(wsBaseURL+"/ws/logs", nil)
			if err != nil {
				select {
				case <-wsCtx.Done():
					return
				case <-time.After(2 * time.Second):
				}
				continue
			}

			for {
				select {
				case <-wsCtx.Done():
					conn.Close()
					return
				default:
				}

				_, msg, err := conn.ReadMessage()
				if err != nil {
					break
				}

				var logData LogMsg
				if err := json.Unmarshal(msg, &logData); err == nil {
					select {
					case LogChannel <- logData:
					default:
					}
				}
			}
			conn.Close()
		}
	}()
}

func WaitForLog() tea.Msg {
	select {
	case msg := <-LogChannel:
		return msg
	case <-time.After(100 * time.Millisecond):
		return nil
	}
}

func FetchStatus() tea.Cmd {
	return func() tea.Msg {
		client := http.Client{Timeout: 5 * time.Second}
		resp, err := client.Get(baseURL + "/api/status")
		if err != nil {
			return ErrorMsg{Err: err}
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return ErrorMsg{Err: err}
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

type ActionSuccessMsg struct {
	Action string
}

type ConfigMsg struct {
	Config map[string]string
}

func FetchConfig() tea.Cmd {
	return func() tea.Msg {
		client := http.Client{Timeout: 5 * time.Second}
		resp, err := client.Get(baseURL + "/api/config")
		if err != nil {
			return ErrorMsg{Err: err}
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		if err != nil {
			return ErrorMsg{Err: err}
		}

		var result struct {
			Status string            `json:"status"`
			Config map[string]string `json:"config"`
		}
		if err := json.Unmarshal(body, &result); err != nil {
			return ErrorMsg{Err: err}
		}
		if result.Status != "ok" {
			return ErrorMsg{Err: fmt.Errorf("config fetch failed: %s", string(body))}
		}
		return ConfigMsg{Config: result.Config}
	}
}

func SetConfig(key, value string) tea.Cmd {
	return func() tea.Msg {
		payload, _ := json.Marshal(map[string]string{"key": key, "value": value})
		client := http.Client{Timeout: 5 * time.Second}
		resp, err := client.Post(baseURL+"/api/config/update", "application/json", strings.NewReader(string(payload)))
		if err != nil {
			return ErrorMsg{Err: err}
		}
		defer resp.Body.Close()
		return ActionSuccessMsg{Action: fmt.Sprintf("config_%s", key)}
	}
}

func RunStep(idx int) tea.Cmd {
	return func() tea.Msg {
		client := http.Client{Timeout: 5 * time.Second}
		url := fmt.Sprintf("%s/api/step/%d/run", baseURL, idx)
		resp, err := client.Post(url, "application/json", nil)
		if err != nil {
			return ErrorMsg{Err: err}
		}
		defer resp.Body.Close()
		return ActionSuccessMsg{Action: fmt.Sprintf("run_step_%d", idx)}
	}
}

func ForceStep(idx int) tea.Cmd {
	return func() tea.Msg {
		client := http.Client{Timeout: 5 * time.Second}
		url := fmt.Sprintf("%s/api/step/%d/force", baseURL, idx)
		resp, err := client.Post(url, "application/json", nil)
		if err != nil {
			return ErrorMsg{Err: err}
		}
		defer resp.Body.Close()
		return ActionSuccessMsg{Action: fmt.Sprintf("force_step_%d", idx)}
	}
}

func ControlAction(action string) tea.Cmd {
	return func() tea.Msg {
		client := http.Client{Timeout: 5 * time.Second}
		url := fmt.Sprintf("%s/api/control/%s", baseURL, action)
		resp, err := client.Post(url, "application/json", nil)
		if err != nil {
			return ErrorMsg{Err: err}
		}
		defer resp.Body.Close()
		return ActionSuccessMsg{Action: fmt.Sprintf("control_%s", action)}
	}
}

func TakeSnapshot(label string) tea.Cmd {
	return func() tea.Msg {
		client := http.Client{Timeout: 5 * time.Second}
		url := fmt.Sprintf("%s/api/snapshots/take?label=%s", baseURL, label)
		resp, err := client.Post(url, "application/json", nil)
		if err != nil {
			return ErrorMsg{Err: err}
		}
		defer resp.Body.Close()
		return ActionSuccessMsg{Action: fmt.Sprintf("snapshot_%s", label)}
	}
}
