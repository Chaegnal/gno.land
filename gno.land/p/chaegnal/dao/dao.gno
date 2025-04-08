package dao

import (
	"std"
	"strconv"

	"gno.land/p/chaegnal/dao"
	"gno.land/p/demo/avl"
)

type Proposal struct {
	Id          int
	Title       string
	Description string
	Options     []string
	Votes       *avl.Tree
	Voters      *avl.Tree
	Deadline    string
	Active      bool
	Winner      string
}

type DAO struct {
	Proposals *avl.Tree
}

func CreateProposals(title, desc, deadline string, options []string) {
	newProposal := Proposal{
		Id:          dao.Proposals.Size() + 1,
		Title:       title,
		Description: desc,
		Options:     options,
		Votes:       avl.NewTree(),
		Voters:      avl.NewTree(),
		Deadline:    deadline,
		Active:      true,
	}

	dao.Proposal.Set(dao.Proposals.Size()+1, newProposal)
}

func (dao *DAO) VoteDao(voteId, choiceIdx int) {
	caller := std.PreviousRealm().Address()

	raw, ok := dao.Proposals.Get(strconv.Itoa(choiceIdx))
	if !ok {
		panic("Vote does not exist")
	}

	vote := raw.(Proposal)

	if !vote.Active {
		panic("Vote already closed")
	}

	_, voted := vote.Voters.Get(caller.String())
	if voted {
		panic("Already voted")
	}

	if choiceIdx < 0 || choiceIdx > len(vote.Options) {
		panic("Invalid voting choice")
	}

	rawVote, _ := vote.Votes.Get(strconv.Itoa(choiceIdx))
	currentVote := rawVote.(int)

	vote.Votes.Set(strconv.Itoa(choiceIdx), currentVote+1)

	vote.Voters.Set(caller.String(), choiceIdx)

	dao.Proposals.Set(strconv.Itoa(voteId), vote)
}
