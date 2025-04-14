package dao

import (
	"std"
	"strconv"

	"gno.land/p/demo/avl"
)

type Proposal struct {
	Id           int
	Title        string
	Description  string
	Owner        std.Address
	Callback     string
	CallbackArgs []string
	Votes        *avl.Tree
	Voters       *avl.Tree
	Active       bool
	Winner       string
}

type WhitelistedUser struct {
	Address std.Address
	Rank    string
}

type DAO struct {
	Proposals        *avl.Tree
	Whitelist        *avl.Tree
	AwaitingApproval *avl.Tree
}

const (
	adminRank  = "admin"
	memberRank = "member"
	VoteYay    = 1
	VoteNay    = 0
)

func NewDAO() *DAO {
	return &DAO{
		Proposals:        avl.NewTree(),
		Whitelist:        avl.NewTree(),
		AwaitingApproval: avl.NewTree(),
	}
}

func (dao *DAO) PendingApproval(adr std.Address) {
	_, ok := dao.AwaitingApproval.Get(adr.String())
	if ok {
		panic("Already awaiting approval.")
	}

	_, ok = dao.IsMember(adr)
	if ok {
		panic("Already whitelisted.")
	}

	dao.AwaitingApproval.Set(adr.String(), true)
}

func (dao *DAO) WhitelistingAwaitingApproval(caller, adr std.Address) {
	if !dao.IsAdmin(caller) {
		panic("Only admins can whitelist members. -> " + caller.String())
	}

	_, ok := dao.AwaitingApproval.Get(adr.String())
	if !ok {
		panic("This address is not awaiting approval.")
	}

	_, isMember := dao.IsMember(adr)
	if isMember {
		panic("Already whitelisted.")
	}

	dao.WhitelistMember(adr)
	dao.AwaitingApproval.Remove(adr.String())
}

func (dao *DAO) RefuseAwaitingMember(caller, adr std.Address) {
	if !dao.IsAdmin(caller) {
		panic("Only admins can refuse members.")
	}

	dao.AwaitingApproval.Remove(adr.String())
}

func (dao *DAO) WhitelistMember(adr std.Address) {
	newWhitelisted := WhitelistedUser{
		Address: adr,
		Rank:    memberRank,
	}

	dao.Whitelist.Set(adr.String(), newWhitelisted)
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

func (dao *DAO) IsPending(adr std.Address) bool {
	_, ok := dao.AwaitingApproval.Get(adr.String())
	if !ok {
		return false
	}
	return true
}

func (dao *DAO) SetAdmin(caller, adr std.Address) {
	if !dao.IsAdmin(caller) {
		panic("Only admins can promote members.")
	}

	dao.DefaultAdmin(adr)
}

func (dao *DAO) DefaultAdmin(adr std.Address) {
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

func (dao *DAO) RemoveAdminRank(caller, adr std.Address) {
	if !dao.IsAdmin(caller) {
		panic("Only admins can demote members.")
	}

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

func (dao *DAO) RemoveMember(caller, adr std.Address) {
	if !dao.IsAdmin(caller) {
		panic("Must be an admin to remove a member.")
	}

	member, ok := dao.IsMember(adr)
	if !ok {
		panic("Not a member.")
	}

	if member.Address == caller {
		panic("You cannot remove yourself.")
	}

	dao.Whitelist.Remove(adr.String())
}

func (dao *DAO) GetWhitelisted() *avl.Tree {
	return dao.Whitelist
}

func (dao *DAO) GetAwaiting() *avl.Tree {
	return dao.AwaitingApproval
}

func (dao *DAO) GetProposals() *avl.Tree {
	return dao.Proposals
}

func (dao *DAO) CreateProposals(title, desc, callback string, callbackArgs []string, caller std.Address) {
	if !dao.IsAdmin(caller) {
		panic("You cannot create proposals")
	}

	newProposal := Proposal{
		Id:           dao.Proposals.Size() + 1,
		Title:        title,
		Description:  desc,
		Owner:        caller,
		Callback:     callback,
		CallbackArgs: callbackArgs,
		Votes:        avl.NewTree(),
		Voters:       avl.NewTree(),
		Active:       true,
	}

	dao.Proposals.Set(strconv.Itoa(dao.Proposals.Size()+1), newProposal)
}

func (dao *DAO) ExecuteCallback(proposal Proposal) {
	if proposal.Callback == "" {
		return
	}

	switch proposal.Callback {
	case "WhitelistingAwaitingApproval":
		if len(proposal.CallbackArgs) < 2 {
			panic("Not enough arguments.")
		}

		dao.WhitelistingAwaitingApproval(std.Address(proposal.CallbackArgs[0]), std.Address(proposal.CallbackArgs[1]))

	case "RefuseAwaitingMember":
		if len(proposal.CallbackArgs) < 2 {
			panic("Not enough arguments.")
		}

		dao.RefuseAwaitingMember(std.Address(proposal.CallbackArgs[0]), std.Address(proposal.CallbackArgs[1]))

	case "SetAdmin":
		if len(proposal.CallbackArgs) < 2 {
			panic("Not enough arguments.")
		}

		dao.SetAdmin(std.Address(proposal.CallbackArgs[0]), std.Address(proposal.CallbackArgs[1]))

	case "RemoveAdminRank":
		if len(proposal.CallbackArgs) < 2 {
			panic("Not enough arguments.")
		}

		dao.RemoveAdminRank(std.Address(proposal.CallbackArgs[0]), std.Address(proposal.CallbackArgs[1]))

	case "RemoveMember":
		if len(proposal.CallbackArgs) < 2 {
			panic("Not enough arguments.")
		}

		dao.RemoveMember(std.Address(proposal.CallbackArgs[0]), std.Address(proposal.CallbackArgs[1]))

	default:
		panic("Unknown callback: " + proposal.Callback)
	}
}

func (dao *DAO) hasEveryoneVoted(vote Proposal) bool {
	if vote.Voters.Size() == dao.Whitelist.Size() {
		return true
	}
	return false
}

func (dao *DAO) VoteProposal(voteId, choiceIdx int, caller std.Address) {
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

	if choiceIdx != VoteYay && choiceIdx != VoteNay {
		panic("Invalid vote. Must be 0 (Nay) or 1 (Yay).")
	}

	rawVote, _ := vote.Votes.Get(strconv.Itoa(choiceIdx))
	currentVote := 0
	if rawVote != nil {
		currentVote = rawVote.(int)
	}

	vote.Votes.Set(strconv.Itoa(choiceIdx), currentVote+1)
	vote.Voters.Set(caller.String(), choiceIdx)

	dao.Proposals.Set(strconv.Itoa(voteId), vote)

	if dao.hasEveryoneVoted(vote) {
		dao.CloseProposal(voteId, caller)
	}
}

func (dao *DAO) CloseProposal(id int, caller std.Address) {
	raw, ok := dao.Proposals.Get(strconv.Itoa(id))
	if !ok {
		panic("Proposal does not exist.")
	}

	closingProp := raw.(Proposal)
	if !closingProp.Active {
		panic("Proposal already closed.")
	}

	ok = dao.IsAdmin(caller)
	if !ok {
		panic("You cannot close a proposal.")
	}

	yayVotesRaw, _ := closingProp.Votes.Get(strconv.Itoa(VoteYay))
	nayVotesRaw, _ := closingProp.Votes.Get(strconv.Itoa(VoteNay))

	yayVotes := 0
	if yayVotesRaw != nil {
		yayVotes = yayVotesRaw.(int)
	}
	nayVotes := 0
	if nayVotesRaw != nil {
		nayVotes = nayVotesRaw.(int)
	}

	if yayVotes > nayVotes {
		closingProp.Winner = "yay"
		dao.ExecuteCallback(closingProp)
	} else {
		closingProp.Winner = "nay"
	}

	closingProp.Active = false
	dao.Proposals.Set(strconv.Itoa(id), closingProp)
}

func (dao *DAO) LeaveGroup(caller std.Address) {
	var adminCounter int

	_, ok := dao.IsMember(caller)
	if !ok {
		panic("Not a member.")
	}

	if dao.IsAdmin(caller) {
		dao.Whitelist.Iterate("", "", func(_ string, val any) bool {
			user := val.(WhitelistedUser)

			if user.Rank == adminRank {
				adminCounter++
			}

			return false
		})
	}

	if adminCounter <= 1 {
		panic("You are the last admin. Assign another admin before leaving.")
	}

	dao.Whitelist.Remove(caller.String())
}
