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
	adminRank  = "admin"
	memberRank = "member"
)

func (dao *DAO) WhitelistMember(adr std.Address, rank string) {
	if rank != adminRank || rank != memberRank {
		panic("Rank does not exist.")
	}

	newWhitelisted := WhitelistedUser{
		Address: adr,
		Rank:    rank,
	}

	dao.Whitelist.Set(strconv.Itoa(dao.Whitelist.Size()+1), newWhitelisted)
}

func (dao *DAO) IsMember(adr std.Address) (WhitelistedUser, bool) {
	raw, ok := dao.Whitelist.Get(adr.String())
	if !ok {
		return WhitelistedUser{}, false
	}

	return raw.(WhitelistedUser), true
}

func (dao *DAO) IsAdmin(adr std.Address) bool {
	isAdmin := false

	member, isMember := dao.IsMember(adr)
	if !isMember {
		return false
	}

	if member.Rank == adminRank {
		isAdmin = true
	}

	return isAdmin
}

func (dao *DAO) SetAdmin(adr std.Address) {
	member, ok := dao.IsMember(adr)

	if dao.IsAdmin(adr) {
		panic("Member is already an admin.")
	}

	if !ok {
		panic("Not a member.")
	}

	member.Rank = adminRank
	dao.Whitelist.Set(adr.String(), member)
}

func (dao *DAO) RemoveAdminRank(adr std.Address) {
	member, ok := dao.IsMember(adr)

	if !dao.IsAdmin(adr) {
		panic("Member is not an admin.")
	}

	if !ok {
		panic("Not a member.")
	}

	member.Rank = memberRank
	dao.Whitelist.Set(adr.String(), member)
}

func (dao *DAO) RemoveMember(adr std.Address) {
	if !dao.IsAdmin(std.PreviousRealm().Address()) {
		panic("Must be an admin to remove a member.")
	}

	member, ok := dao.IsMember(adr)
	if !ok {
		panic("Not a member.")
	}

	if member.Address == std.PreviousRealm().Address() {
		panic("You cannot remove yourself.")
	}

	dao.Whitelist.Remove(adr.String())
}

func (dao *DAO) CreateProposals(title, desc string, options []string) {
	if !dao.IsAdmin(std.PreviousRealm().Address()) {
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
		Active:      true,
	}

	dao.Proposals.Set(strconv.Itoa(dao.Proposals.Size()+1), newProposal)
}

func (dao *DAO) hasEveryoneVoted(vote Proposal) bool {
	if vote.Voters.Size() == dao.Whitelist.Size() {
		return true
	}
	return false
}

func (dao *DAO) VoteProposal(voteId, choiceIdx int) {
	caller := std.PreviousRealm().Address()

	_, ok := dao.IsMember(caller)
	if !ok {
		panic("You are not whitelisted.")
	}

	raw, ok := dao.Proposals.Get(strconv.Itoa(voteId))
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

	if choiceIdx < 0 || choiceIdx >= len(vote.Options) {
		panic("Invalid voting choice.")
	}

	rawVote, _ := vote.Votes.Get(strconv.Itoa(choiceIdx))
	currentVote := rawVote.(int)

	vote.Votes.Set(strconv.Itoa(choiceIdx), currentVote+1)
	vote.Voters.Set(caller.String(), choiceIdx)

	dao.Proposals.Set(strconv.Itoa(voteId), vote)

	if dao.hasEveryoneVoted(vote) {
		dao.CloseProposal(voteId)
	}
}

func (dao *DAO) CloseProposal(id int) {
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

	ok = dao.IsAdmin(std.PreviousRealm().Address())
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
