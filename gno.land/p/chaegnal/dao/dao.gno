package dao

import (
	"std"
	"strconv"

	"gno.land/p/demo/avl"
)

type Proposal struct {
	Id          int
	Title       string
	Description string
	Owner       std.Address
	Options     []string
	Votes       *avl.Tree
	Voters      *avl.Tree
	Deadline    string
	Active      bool
	Winner      string
}

type WhitelistedUser struct {
	Address std.Address
	Rank    string
}

type DAO struct {
	Proposals *avl.Tree
	Whitelist *avl.Tree
}

const (
	admin  = "admin"
	member = "member"
)

func (dao *DAO) whitelistMember(adr std.Address, rank string) {
	if rank != admin || rank != member {
		panic("Rank does not exist.")
	}

	newWhitelisted := WhitelistedUser{
		Address: adr,
		Rank:    rank,
	}

	dao.Whitelist.Set(strconv.Itoa(dao.Whitelist.Size()+1), newWhitelisted)
}

func (dao *DAO) isMember(adr std.Address) (WhitelistedUser, bool) {
	raw, ok := dao.Whitelist.Get(adr.String())
	if !ok {
		return WhitelistedUser{}, false
	}

	return raw.(WhitelistedUser), true
}

func (dao *DAO) isAdmin(adr std.Address) bool {
	isAdmin := false

	member, isMember := dao.isMember(adr)
	if !isMember {
		return false
	}

	if member.Rank == admin {
		isAdmin = true
	}

	return isAdmin
}

func (dao *DAO) CreateProposals(title, desc, deadline string, options []string) {
	if !dao.isAdmin(std.PreviousRealm().Address()) {
		panic("You cannot create proposals")
	}

	newProposal := Proposal{
		Id:          dao.Proposals.Size() + 1,
		Title:       title,
		Description: desc,
		Owner:       std.PreviousRealm().Address(),
		Options:     options,
		Votes:       avl.NewTree(),
		Voters:      avl.NewTree(),
		Deadline:    deadline,
		Active:      true,
	}

	dao.Proposals.Set(strconv.Itoa(dao.Proposals.Size()+1), newProposal)
}

func (dao *DAO) VoteProposal(voteId, choiceIdx int) {
	caller := std.PreviousRealm().Address()

	_, ok := dao.isMember(caller)
	if !ok {
		panic("You are not whitelisted.")
	}

	raw, ok := dao.Proposals.Get(strconv.Itoa(choiceIdx))
	if !ok {
		panic("Proposal does not exist.")
	}

	vote := raw.(Proposal)

	if !vote.Active {
		panic("Proposal already closed.")
	}

	_, voted := vote.Voters.Get(caller.String())
	if voted {
		panic("Already voted.")
	}

	if choiceIdx < 0 || choiceIdx > len(vote.Options) {
		panic("Invalid voting choice.")
	}

	rawVote, _ := vote.Votes.Get(strconv.Itoa(choiceIdx))
	currentVote := rawVote.(int)

	vote.Votes.Set(strconv.Itoa(choiceIdx), currentVote+1)
	vote.Voters.Set(caller.String(), choiceIdx)

	dao.Proposals.Set(strconv.Itoa(voteId), vote)
}

func (dao *DAO) closeProposal(id int) {
	var winnerVote int
	var winnerIdx int

	raw, ok := dao.Proposals.Get(strconv.Itoa(id))
	if !ok {
		panic("Proposal does not exist.")
	}

	closingProp := raw.(Proposal)
	if !closingProp.Active {
		panic("Proposal already closed.")
	}

	ok = dao.isAdmin(std.PreviousRealm().Address())
	if !ok {
		panic("You cannot close a proposal.")
	}

	closingProp.Votes.Iterate("", "", func(indexStr string, val any) bool {
		vote := val.(int)
		index, err := strconv.Atoi(indexStr)
		if err != nil {
			panic("Invalid index.")
		}

		if vote > winnerVote {
			winnerVote = vote
			winnerIdx = index
		}

		return false
	})

	if winnerIdx >= 0 && winnerIdx < len(closingProp.Options) {
		closingProp.Winner = closingProp.Options[winnerIdx]
	} else {
		closingProp.Winner = "No winner"
	}

	closingProp.Active = false
	dao.Proposals.Set(strconv.Itoa(id), closingProp)
}
