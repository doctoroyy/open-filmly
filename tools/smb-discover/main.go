package main

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"regexp"
	"runtime"
	"strings"
	"time"
)

type ShareInfo struct {
	Name    string `json:"name"`
	Type    string `json:"type"`
	Comment string `json:"comment,omitempty"`
}

type DiscoveryResult struct {
	Host      string      `json:"host"`
	Port      int         `json:"port"`
	Success   bool        `json:"success"`
	Shares    []ShareInfo `json:"shares"`
	Error     string      `json:"error,omitempty"`
	Timestamp string      `json:"timestamp"`
	Method    string      `json:"method"`
}

type TestResult struct {
	Host      string `json:"host"`
	Port      int    `json:"port"`
	Success   bool   `json:"success"`
	Error     string `json:"error,omitempty"`
	Timestamp string `json:"timestamp"`
}

func main() {
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	command := os.Args[1]

	switch command {
	case "discover":
		handleDiscoverCommand()
	case "test":
		handleTestCommand()
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", command)
		printUsage()
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Fprintf(os.Stderr, "Usage:\n")
	fmt.Fprintf(os.Stderr, "  %s discover <host> <username> <password> [domain] [port]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "  %s test <host> [port]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "\nExamples:\n")
	fmt.Fprintf(os.Stderr, "  %s discover 192.168.1.100 guest '' WORKGROUP\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "  %s test 192.168.1.100\n", os.Args[0])
}

func handleDiscoverCommand() {
	if len(os.Args) < 5 {
		fmt.Fprintf(os.Stderr, "discover command requires: host username password [domain] [port]\n")
		os.Exit(1)
	}

	host := os.Args[2]
	username := os.Args[3]
	password := os.Args[4]
	domain := "WORKGROUP"
	port := 445

	if len(os.Args) > 5 && os.Args[5] != "" {
		domain = os.Args[5]
	}
	if len(os.Args) > 6 {
		fmt.Sscanf(os.Args[6], "%d", &port)
	}

	result := discoverShares(host, port, username, password, domain)
	outputJSON(result)
}

func handleTestCommand() {
	if len(os.Args) < 3 {
		fmt.Fprintf(os.Stderr, "test command requires: host [port]\n")
		os.Exit(1)
	}

	host := os.Args[2]
	port := 445

	if len(os.Args) > 3 {
		fmt.Sscanf(os.Args[3], "%d", &port)
	}

	result := testConnection(host, port)
	outputJSON(result)
}

func testConnection(host string, port int) TestResult {
	result := TestResult{
		Host:      host,
		Port:      port,
		Timestamp: time.Now().Format(time.RFC3339),
	}

	// Test basic TCP connectivity
	address := fmt.Sprintf("%s:%d", host, port)
	conn, err := net.DialTimeout("tcp", address, 5*time.Second)
	if err != nil {
		result.Error = fmt.Sprintf("TCP connection failed: %v", err)
		return result
	}
	conn.Close()

	result.Success = true
	return result
}

func discoverShares(host string, port int, username, password, domain string) DiscoveryResult {
	result := DiscoveryResult{
		Host:      host,
		Port:      port,
		Timestamp: time.Now().Format(time.RFC3339),
	}

	// 首先测试连接
	if !testConnection(host, port).Success {
		result.Error = "无法连接到SMB端口"
		return result
	}

	var shares []ShareInfo
	var method string
	var err error

	// 尝试不同的发现方法
	switch runtime.GOOS {
	case "darwin":
		shares, err = discoverSharesMacOS(host, username, password, domain)
		method = "macOS smbutil"
	case "linux":
		shares, err = discoverSharesLinux(host, username, password, domain)
		method = "Linux smbclient"
	case "windows":
		shares, err = discoverSharesWindows(host, username, password, domain)
		method = "Windows net view"
	default:
		err = fmt.Errorf("unsupported platform: %s", runtime.GOOS)
	}

	if err != nil {
		result.Error = err.Error()
		result.Method = method + " (failed)"
		return result
	}

	result.Shares = shares
	result.Success = true
	result.Method = method
	return result
}

func discoverSharesMacOS(host, username, password, domain string) ([]ShareInfo, error) {
	// 使用smbutil (macOS内置工具)
	var cmd *exec.Cmd
	
	if username == "" || username == "guest" || password == "" {
		// 匿名访问 - 明确使用guest用户和空密码
		cmd = exec.Command("smbutil", "view", "-N", fmt.Sprintf("//guest@%s", host))
	} else {
		// 使用用户名密码
		var userSpec string
		if domain != "" && domain != "WORKGROUP" {
			userSpec = fmt.Sprintf("%s;%s", domain, username)
		} else {
			userSpec = username
		}
		
		// 创建临时的认证文件（更安全）
		authString := fmt.Sprintf("//%s@%s", userSpec, host)
		cmd = exec.Command("smbutil", "view", authString)
		
		// 如果有密码，通过环境变量传递
		if password != "" {
			cmd.Env = append(os.Environ(), fmt.Sprintf("SMB_PASSWORD=%s", password))
		}
	}

	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("smbutil failed: %v, output: %s", err, output)
	}

	return parseSmbUtilOutput(string(output)), nil
}

func discoverSharesLinux(host, username, password, domain string) ([]ShareInfo, error) {
	// 使用smbclient (需要安装samba-client)
	args := []string{"-L", host, "-N"} // -N for no password prompt
	
	if username != "" && username != "guest" {
		args = []string{"-L", host, "-U", username}
		if password != "" {
			// 通过stdin传递密码会更安全，但这里为了简化直接用参数
			args = append(args, fmt.Sprintf("%%%s", password))
		}
	}
	
	if domain != "" && domain != "WORKGROUP" {
		args = append(args, "-W", domain)
	}

	cmd := exec.Command("smbclient", args...)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("smbclient failed: %v, output: %s", err, output)
	}

	return parseSmbClientOutput(string(output)), nil
}

func discoverSharesWindows(host, username, password, domain string) ([]ShareInfo, error) {
	// 使用net view命令
	var cmd *exec.Cmd
	
	if username == "" || username == "guest" {
		cmd = exec.Command("net", "view", fmt.Sprintf("\\\\%s", host))
	} else {
		// Windows net view with credentials is complex, fall back to basic
		cmd = exec.Command("net", "view", fmt.Sprintf("\\\\%s", host))
	}

	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("net view failed: %v, output: %s", err, output)
	}

	return parseNetViewOutput(string(output)), nil
}

func parseSmbUtilOutput(output string) []ShareInfo {
	var shares []ShareInfo
	lines := strings.Split(output, "\n")
	
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "//") || strings.Contains(line, "Server") {
			continue
		}
		
		// macOS smbutil输出格式相对简单
		if strings.Contains(line, "Disk") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				shareName := parts[0]
				shares = append(shares, ShareInfo{
					Name: shareName,
					Type: "Disk",
				})
			}
		}
	}
	
	return shares
}

func parseSmbClientOutput(output string) []ShareInfo {
	var shares []ShareInfo
	lines := strings.Split(output, "\n")
	
	for _, line := range lines {
		line = strings.TrimSpace(line)
		
		// 查找包含Disk的行
		if strings.Contains(line, "Disk") {
			// smbclient输出格式: "sharename    Disk    comment"
			re := regexp.MustCompile(`^\s*(\S+)\s+Disk\s*(.*)$`)
			matches := re.FindStringSubmatch(line)
			if len(matches) >= 2 {
				shareName := matches[1]
				comment := ""
				if len(matches) > 2 {
					comment = strings.TrimSpace(matches[2])
				}
				
				shares = append(shares, ShareInfo{
					Name:    shareName,
					Type:    "Disk", 
					Comment: comment,
				})
			}
		}
	}
	
	return shares
}

func parseNetViewOutput(output string) []ShareInfo {
	var shares []ShareInfo
	lines := strings.Split(output, "\n")
	
	for _, line := range lines {
		line = strings.TrimSpace(line)
		
		// Windows net view输出格式
		if strings.Contains(line, "Disk") {
			parts := strings.Fields(line)
			if len(parts) >= 2 {
				shareName := parts[0]
				shares = append(shares, ShareInfo{
					Name: shareName,
					Type: "Disk",
				})
			}
		}
	}
	
	return shares
}

func outputJSON(data interface{}) {
	jsonBytes, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "JSON marshalling error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(string(jsonBytes))
}