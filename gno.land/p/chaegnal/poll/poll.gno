package poll

import (
	"std"

	"gno.land/p/demo/avl"
)

type Poll struct {
	Title      string
	Question   string
	VotersTree *avl.Tree
}

func (p *Poll) HasVoted(address std.Address) (bool, bool) {
	vote, exists := p.Voters().Get(address.String())
	if exists {
		return true, vote.(bool)
	}
	return false, false
}

func (p Poll) Voters() *avl.Tree {
	return p.VotersTree
}

func (p Poll) VoteCount() (int, int) {
	var yay int

	p.Voters().Iterate("", "", func(key string, value interface{}) bool {
		vote := value.(bool)
		if vote == true {
			yay = yay + 1
		}

		return false
	})
	return yay, p.Voters().Size() - yay
}

func (p *Poll) Vote(voter std.Address, vote bool) {
	p.Voters().Set(voter.String(), vote)
}
