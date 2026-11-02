//go:build !(darwin || linux) || android || openharmony

package main

func initOwnership(homeDir string) {}

func scheduleReclaimOwnership() {}
