package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"strings"
	"time"

	"github.com/cloudsoda/go-smb2"
)

type ShareInfo struct {
	Name        string `json:"name"`
	Type        string `json:"type"`
	Comment     string `json:"comment,omitempty"`
	Permissions string `json:"permissions,omitempty"`
}

type DiscoveryResult struct {
	Host      string      `json:"host"`
	Port      int         `json:"port"`
	Success   bool        `json:"success"`
	Shares    []ShareInfo `json:"shares"`
	Error     string      `json:"error,omitempty"`
	Timestamp string      `json:"timestamp"`
}

type DirectoryItem struct {
	Name         string `json:"name"`
	IsDirectory  bool   `json:"isDirectory"`
	Size         int64  `json:"size"`
	ModifiedTime string `json:"modifiedTime"`
}

type DirectoryResult struct {
	Path    string          `json:"path"`
	Success bool            `json:"success"`
	Items   []DirectoryItem `json:"items"`
	Error   string          `json:"error,omitempty"`
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
	case "list":
		handleListCommand()
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
	fmt.Fprintf(os.Stderr, "  %s list <host> <sharename> <path> <username> <password> [domain] [port]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "  %s test <host> [port]\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "\nExamples:\n")
	fmt.Fprintf(os.Stderr, "  %s discover 192.168.1.100 guest '' WORKGROUP\n", os.Args[0])
	fmt.Fprintf(os.Stderr, "  %s list 192.168.1.100 media / guest ''\n", os.Args[0])
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
	domain := ""
	port := 445

	if len(os.Args) > 5 {
		domain = os.Args[5]
	}
	if len(os.Args) > 6 {
		fmt.Sscanf(os.Args[6], "%d", &port)
	}

	result := discoverShares(host, port, username, password, domain)
	outputJSON(result)
}

func handleListCommand() {
	if len(os.Args) < 7 {
		fmt.Fprintf(os.Stderr, "list command requires: host sharename path username password [domain] [port]\n")
		os.Exit(1)
	}

	host := os.Args[2]
	sharename := os.Args[3]
	path := os.Args[4]
	username := os.Args[5]
	password := os.Args[6]
	domain := ""
	port := 445

	if len(os.Args) > 7 {
		domain = os.Args[7]
	}
	if len(os.Args) > 8 {
		fmt.Sscanf(os.Args[8], "%d", &port)
	}

	result := listDirectory(host, port, sharename, path, username, password, domain)
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

func testConnection(host string, port int) map[string]interface{} {
	result := map[string]interface{}{
		"host":      host,
		"port":      port,
		"timestamp": time.Now().Format(time.RFC3339),
	}

	// Test basic TCP connectivity
	address := fmt.Sprintf("%s:%d", host, port)
	conn, err := net.DialTimeout("tcp", address, 5*time.Second)
	if err != nil {
		result["success"] = false
		result["error"] = fmt.Sprintf("TCP connection failed: %v", err)
		return result
	}
	conn.Close()

	result["success"] = true
	result["message"] = "TCP connection successful"
	return result
}

func discoverShares(host string, port int, username, password, domain string) DiscoveryResult {
	result := DiscoveryResult{
		Host:      host,
		Port:      port,
		Timestamp: time.Now().Format(time.RFC3339),
	}

	address := fmt.Sprintf("%s:%d", host, port)

	// Create SMB dialer
	d := &smb2.Dialer{
		Initiator: &smb2.NTLMInitiator{
			User:     username,
			Password: password,
			Domain:   domain,
		},
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Establish SMB session
	s, err := d.Dial(ctx, address)
	if err != nil {
		result.Error = fmt.Sprintf("SMB authentication failed: %v", err)
		return result
	}
	defer s.Logoff()

	// Discover shares
	shareNames, err := s.ListSharenames()
	if err != nil {
		result.Error = fmt.Sprintf("Failed to list shares: %v", err)
		return result
	}

	// Convert to ShareInfo structs
	for _, name := range shareNames {
		share := ShareInfo{
			Name: name,
			Type: "Disk", // SMB2 doesn't provide detailed type info easily
		}
		result.Shares = append(result.Shares, share)
	}

	result.Success = true
	return result
}

func listDirectory(host string, port int, sharename, dirPath, username, password, domain string) DirectoryResult {
	result := DirectoryResult{
		Path: dirPath,
	}

	address := fmt.Sprintf("%s:%d", host, port)

	// Create SMB dialer
	d := &smb2.Dialer{
		Initiator: &smb2.NTLMInitiator{
			User:     username,
			Password: password,
			Domain:   domain,
		},
	}

	// Create context with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Establish SMB session
	s, err := d.Dial(ctx, address)
	if err != nil {
		result.Error = fmt.Sprintf("SMB authentication failed: %v", err)
		return result
	}
	defer s.Logoff()

	// Mount the share
	share, err := s.Mount(sharename)
	if err != nil {
		result.Error = fmt.Sprintf("Failed to mount share '%s': %v", sharename, err)
		return result
	}
	defer share.Umount()

	// List directory contents
	// Normalize path for SMB operations
	readPath := dirPath
	if readPath == "/" {
		readPath = "."  // Use current directory notation for root
	} else if strings.HasPrefix(readPath, "/") {
		// Remove leading slash and use relative path
		readPath = readPath[1:]
	}
	
	files, err := share.ReadDir(readPath)
	if err != nil {
		result.Error = fmt.Sprintf("Failed to read directory '%s': %v", dirPath, err)
		return result
	}

	// Convert to DirectoryItem structs
	for _, file := range files {
		item := DirectoryItem{
			Name:         file.Name(),
			IsDirectory:  file.IsDir(),
			Size:         file.Size(),
			ModifiedTime: file.ModTime().Format(time.RFC3339),
		}
		result.Items = append(result.Items, item)
	}

	result.Success = true
	return result
}

func outputJSON(data interface{}) {
	jsonBytes, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		fmt.Fprintf(os.Stderr, "JSON marshalling error: %v\n", err)
		os.Exit(1)
	}
	fmt.Println(string(jsonBytes))
}