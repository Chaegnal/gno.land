package ownrandom

import (
	"std"
	"time"
)

func RandomNbr() int64 {
	chainHeight := std.ChainHeight()
	currentTime := time.Now().Unix()

	return (currentTime + chainHeight) % 100
}
