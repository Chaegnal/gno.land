package organizer

import (
	"std"
	"strconv"

	"gno.land/p/chaegnal/dao"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/avl/pager"
	"gno.land/p/demo/ownable"
	"gno.land/p/moul/md"
	"gno.land/p/moul/mdtable"
	"gno.land/p/moul/txlink"
	"gno.land/r/sys/users"
)

type AllGroups struct {
	Groups *avl.Tree
}

type FriendGroup struct {
	ID    int
	Title string
	Owner *ownable.Ownable
	DAO   *dao.DAO
}

type Activity struct {
	ID            int
	Title         string
	Description   string
	AvailableTime []string
	Votes         *avl.Tree
	Participants  *avl.Tree
	Deadline      string
	ChosenTime    string
	Active        bool
}

const (
	pageSize = 5
	VoteYay  = 1
	VoteNay  = 0
)

var (
	ListGroups      AllGroups
	AddressLoggedIn std.Address
)

func init() {
	ListGroups.Groups = avl.NewTree()
}

func CreateFriendGroup(title string) {
	caller := std.PreviousRealm().Address()

	newDao := dao.NewDAO()
	newDao.WhitelistMember(caller)
	newDao.DefaultAdmin(caller)

	newGroup := FriendGroup{
		ID:    ListGroups.Groups.Size() + 1,
		Title: title,
		Owner: ownable.NewWithAddress(caller),
		DAO:   newDao,
	}

	ListGroups.Groups.Set(strconv.Itoa(newGroup.ID), newGroup)
}

func containsValue(tree *avl.Tree, value string) bool {
	found := false

	tree.Iterate("", "", func(key string, val any) bool {
		addr, ok := val.(std.Address)
		if ok && addr.String() == value {
			found = true
			return true
		}
		return false
	})

	return found
}

func AskJoinFriendGroup(groupId int) {
	txSender := std.OriginCaller()

	raw, exists := ListGroups.Groups.Get(strconv.Itoa(groupId))
	if !exists {
		panic("Group does not exist")
	}

	group := raw.(FriendGroup)

	_, ok := group.DAO.IsMember(txSender)
	if ok {
		panic("You are already part of this FriendGroup")
	}

	group.DAO.PendingApproval(txSender)
	ListGroups.Groups.Set(strconv.Itoa(groupId), group)
}

func displayGroupDetails(key string, value interface{}, out *string) {
	group := value.(FriendGroup)

	*out += md.Paragraph("Group Title: " + group.Title + " created by: " + group.Owner.Owner().String())
	*out += "\n"
}

func ResolveAddressName(addr std.Address) string {
	user := users.ResolveAddress(addr)
	if user != nil {
		return user.Name()
	}
	return addr.String()
}

func displayAllExistingGroups(pageNumber, pageSize int) string {
	var out string

	pager := pager.NewPager(ListGroups.Groups, pageSize, false)

	page := pager.GetPage(pageNumber)

	if page.TotalItems == 0 {
		out += "No friend groups available.\n"
		return out
	}

	for _, item := range page.Items {
		group, ok := item.Value.(FriendGroup)
		if !ok {
			continue
		}

		author := ResolveAddressName(group.Owner.Owner())

		out += md.H3("Group: "+group.Title+" - By: "+author) + "\n"
		out += md.Paragraph("Number of friends in the group: "+strconv.Itoa(group.DAO.Whitelist.Size())) + "\n"

		if AddressLoggedIn != "" {
			_, ok = group.DAO.IsMember(AddressLoggedIn)
			if ok {
				out += md.Paragraph("You already are part of this group")
			} else if group.DAO.IsPending(AddressLoggedIn) {
				out += md.Paragraph("You are awaiting approval for this group")
			} else {
				out += md.Link("Join Group", txlink.Call("AskJoinFriendGroup", "groupId", strconv.Itoa(group.ID))) + "\n\n"
			}
		}

		out += md.HorizontalRule() + "\n"
	}

	out += page.Picker("/organizer")

	return out
}

func getGroupFromId(groupId string) FriendGroup {
	convertedId, err := strconv.Atoi(groupId)
	if err != nil {
		panic("Invalid ID")
	}

	raw, found := ListGroups.Groups.Get(strconv.Itoa(convertedId))
	if !found {
		panic("Could not find group")
	}

	return raw.(FriendGroup)
}

func LeaveGroup(groupId string) {
	group := getGroupFromId(groupId)

	group.DAO.LeaveGroup(AddressLoggedIn)
}

func displayGroupInfo(group FriendGroup, table *mdtable.Table, hasJoined bool) {
	author := ResolveAddressName(group.Owner.Owner())
	var view string

	if hasJoined {
		view = md.Link("View", "/r/chaegnal/organizer/group?groupId="+strconv.Itoa(group.ID)) + " | " + md.Link("Leave", txlink.Call("LeaveGroup", "groupId", strconv.Itoa(group.ID)))
	} else {
		view = "You cannot view group yet"
	}

	table.Append([]string{group.Title, author, strconv.Itoa(group.DAO.Whitelist.Size()), view})
}

func displayJoinedGroups() string {
	var out string
	found := false

	out += md.H2("Your Joined Groups") + "\n"
	table := &mdtable.Table{
		Headers: []string{"Title", "Created By", "Members", "Inspect"},
	}

	ListGroups.Groups.Iterate("", "", func(key string, val any) bool {
		group := val.(FriendGroup)

		_, ok := group.DAO.IsMember(AddressLoggedIn)
		if ok {
			displayGroupInfo(group, table, true)
			found = true
		}

		return false
	})

	if !found {
		out = md.Paragraph("You haven't joined any groups yet.")
	} else {
		out += table.String()
	}

	return out
}

func displayPendingApproval() string {
	var out string
	found := false

	table := &mdtable.Table{
		Headers: []string{"Title", "Created By", "Members", "Inspect"},
	}

	ListGroups.Groups.Iterate("", "", func(key string, val any) bool {
		group := val.(FriendGroup)

		if group.DAO.IsPending(AddressLoggedIn) {
			displayGroupInfo(group, table, false)
			found = true
		}
		return false
	})

	if !found {
		out = md.Paragraph("No pending join request.")
	} else {
		out += table.String()
	}

	return out
}

func Login() {
	AddressLoggedIn = std.OriginCaller()
}

func Logout() {
	AddressLoggedIn = ""
}

func Render(rawURL string) string {
	var out string

	pageNumber, size, err := pager.NewPager(ListGroups.Groups, pageSize, false).ParseQuery(rawURL)
	if err != nil {
		pageNumber = 1
	}

	out += md.H1("Welcome to Friendly Organizer")
	out += md.Paragraph("Here you can join and create FriendGroups to organize your next hangout")

	out += md.Paragraph(md.Link("Create New FriendGroup", txlink.Call("CreateFriendGroup", "title")))

	if AddressLoggedIn == "" {
		out += md.H2(md.Link("Login to see your joined group", txlink.Call("Login")))
	} else {
		out += displayJoinedGroups()
		out += md.H2("Your Pending Request")
		out += displayPendingApproval()
	}

	out += md.H2("List of FriendGroups")

	out += displayAllExistingGroups(pageNumber, size)

	if AddressLoggedIn != "" {
		out += md.Paragraph(md.Link("Logout", txlink.Call("Logout")))
	}

	return out
}
