package group

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/moul/mdtable"
	"gno.land/p/moul/txlink"
	"gno.land/p/sunspirit/md"

	"gno.land/r/chaegnal/organizer"
)

func parseQuery(url string) string {
	groupId := strings.SplitAfter(url, "?")
	foundId := strings.SplitAfter(groupId[1], "=")

	return foundId[1]
}

func getGroupFromUrl(url string) organizer.FriendGroup {
	groupId := parseQuery(url)
	if groupId == "" {
		panic("No groupId provided")
	}

	convertedId, err := strconv.Atoi(groupId)
	if err != nil {
		panic("Invalid ID")
	}

	raw, found := organizer.ListGroups.Groups.Get(strconv.Itoa(convertedId))
	if !found {
		panic("Could not find group")
	}

	return raw.(organizer.FriendGroup)
}

func getGroupFromId(groupId string) organizer.FriendGroup {
	convertedId, err := strconv.Atoi(groupId)
	if err != nil {
		panic("Invalid ID")
	}

	raw, found := organizer.ListGroups.Groups.Get(strconv.Itoa(convertedId))
	if !found {
		panic("Could not find group")
	}

	return raw.(organizer.FriendGroup)
}

func AcceptAwaitingMember(groupId string, adr std.Address) {
	group := getGroupFromId(groupId)

	group.DAO.WhitelistingAwaitingApproval(organizer.AddressLoggedIn, adr)
}

func RefuseAwaitingMember(groupId string, adr std.Address) {
	group := getGroupFromId(groupId)

	group.DAO.RefuseAwaitingMember(organizer.AddressLoggedIn, adr)
}

func displayPendingApproval(group organizer.FriendGroup) string {
	awaiting := group.DAO.GetAwaiting()

	table := mdtable.Table{
		Headers: []string{"Address", "Inspect"},
	}

	awaiting.Iterate("", "", func(indexStr string, val any) bool {
		adr := std.Address(indexStr)

		table.Append([]string{adr.String(),
			md.Link("Approve", txlink.Call("AcceptAwaitingMember", "groupId", strconv.Itoa(group.ID), "adr", adr.String())) + " | " +
				md.Link("Reject", txlink.Call("RefuseAwaitingMember", "groupId", strconv.Itoa(group.ID), "adr", adr.String())),
		})
		return false
	})

	return table.String()
}

func RemoveMember(groupId string, adr std.Address) {
	group := getGroupFromId(groupId)

	group.DAO.RemoveMember(organizer.AddressLoggedIn, adr)
}

func MakeAdmin(groupId string, adr std.Address) {
	group := getGroupFromId(groupId)

	group.DAO.SetAdmin(organizer.AddressLoggedIn, adr)
}

func RemoveAdminRank(groupId string, adr std.Address) {
	group := getGroupFromId(groupId)

	group.DAO.RemoveAdminRank(organizer.AddressLoggedIn, adr)
}

func displayMembers(group organizer.FriendGroup) string {
	whitelist := group.DAO.GetWhitelisted()

	table := mdtable.Table{
		Headers: []string{"Address", "Action"},
	}

	whitelist.Iterate("", "", func(indexStr string, val any) bool {
		var actionAdmin string

		adr := std.Address(indexStr)
		if adr == organizer.AddressLoggedIn {
			return false
		}

		if group.DAO.IsAdmin(adr) {
			actionAdmin = md.Link("Remove Admin", txlink.Call("RemoveAdminRank", "groupId", strconv.Itoa(group.ID), "adr", adr.String()))
		} else {
			actionAdmin = md.Link("Make Admin", txlink.Call("MakeAdmin", "groupId", strconv.Itoa(group.ID), "adr", adr.String()))
		}

		table.Append([]string{adr.String(),
			actionAdmin + " | " +
				md.Link("Kick out", txlink.Call("RemoveMember", "groupId", strconv.Itoa(group.ID), "adr", adr.String())),
		})

		return false
	})

	return table.String()
}

func displayAdminBoard(group organizer.FriendGroup) string {
	var out string

	out += md.H2("Admin Board") + "\n"
	out += md.H3("Approval Waitlist") + "\n"

	if group.DAO.GetAwaiting().Size() > 0 {
		out += displayPendingApproval(group)
	} else {
		out += md.Paragraph("No member waiting for approval") + "\n"
	}
	out += md.HorizontalRule() + "\n"

	out += md.H3("Members") + "\n"
	if group.DAO.GetWhitelisted().Size() > 1 {
		out += displayMembers(group)
	} else {
		out += md.Paragraph("No member beside yourself") + "\n"
	}
	out += md.HorizontalRule() + "\n"

	return out
}

func Render(url string) string {
	var out string

	group := getGroupFromUrl(url)

	out += md.H1("Group: " + group.Title)
	out += md.H2("Created by: " + organizer.ResolveAddressName(group.Owner.Owner()))
	out += md.Paragraph("Number of friends: "+strconv.Itoa(group.DAO.Whitelist.Size())) + "\n"
	out += md.HorizontalRule()

	if group.DAO.IsAdmin(organizer.AddressLoggedIn) {
		out += displayAdminBoard(group)
	}

	out += md.H2("Active DAOs")
	out += md.HorizontalRule()

	out += md.H2("Closed DAOs")
	out += md.HorizontalRule()

	out += md.Paragraph(md.Link("Go back", "/r/chaegnal/organizer"))

	return out
}
