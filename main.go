package main

import "github.com/sutekar/es2os/cmd"

var (
	version   = "0.1.0"
	buildTime = "dev"
)

func main() {
	cmd.SetVersionInfo(version, buildTime)
	cmd.Execute()
}
